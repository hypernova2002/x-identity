# A single-use, expiring token sent to a user (email links and codes) or held briefly by a client
# (sign-in challenges). Only digests are stored; plaintexts are returned once by {.issue!}.
#
# End-user emails carry both a 6-digit code and an opaque token for links. The code is short, so it
# is HMAC-hashed with the app secret and allows only a few wrong guesses.
class OneTimeToken < ApplicationRecord
  TTLS = {
    "email_verification" => 24.hours,
    "password_reset" => 1.hour,
    "email_change" => 1.hour,
    "invitation" => 7.days,
    "sign_in_challenge" => 5.minutes,
    "provider_authorization" => 10.minutes,
    "provider_code" => 1.minute,
    "oidc_interaction" => 30.minutes,
    "oidc_login_ticket" => 2.minutes,
    "oidc_code" => 1.minute,
    "saml_logout" => 10.minutes
  }.freeze
  CODE_GENERATION_TRIES = 10

  Issued = Data.define(:record, :token, :code)

  belongs_to :subject, polymorphic: true

  enum :purpose, TTLS.keys.index_by(&:itself), validate: true

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :usable, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  # @param token [String]
  # @return [String]
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # @param code [String]
  # @return [String]
  def self.code_digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, code.to_s)
  end

  # Issues a token, by default invalidating the subject's earlier unused tokens with the same purpose.
  # @param subject [ApplicationRecord]
  # @param purpose [String, Symbol]
  # @param data [Hash]
  # @param replace [Boolean] false keeps earlier tokens usable, e.g. for concurrent sign-ins
  # @return [Array(OneTimeToken, String)] the record and its plaintext token
  def self.issue!(subject:, purpose:, data: {}, replace: true)
    issued = issue_with_code!(subject: subject, purpose: purpose, data: data, with_code: false, replace: replace)
    [ issued.record, issued.token ]
  end

  # Like {.issue!}, optionally also generating a 6-digit code.
  # @param reject_code [#call, nil] returns true for codes that mustn't be sent (e.g. ones currently
  #   blocked for too many wrong guesses); another random code is tried instead
  # @return [Issued]
  def self.issue_with_code!(subject:, purpose:, data: {}, with_code: true, reject_code: nil, replace: true)
    purpose = purpose.to_s
    token = SecureRandom.base58(32)
    code = generate_code(reject_code) if with_code

    record = transaction do
      usable.where(subject: subject, purpose: purpose).update_all(consumed_at: Time.current) if replace
      Prunable.delete_batch(where(subject: subject, purpose: purpose).where("consumed_at IS NOT NULL OR expires_at < ?", Time.current))
      create!(
        subject: subject,
        purpose: purpose,
        data: data,
        token_digest: digest(token),
        code_digest: code && code_digest(code),
        expires_at: TTLS.fetch(purpose).from_now
      )
    end

    Issued.new(record: record, token: token, code: code)
  end

  # @param reject_code [#call, nil]
  # @return [String]
  def self.generate_code(reject_code)
    code = nil
    CODE_GENERATION_TRIES.times do
      code = format("%06d", SecureRandom.random_number(1_000_000))
      break unless reject_code&.call(code)
    end
    code
  end

  # @param token [String]
  # @param purpose [String, Symbol]
  # @return [OneTimeToken, nil]
  def self.find_usable(token, purpose:)
    usable.find_by(token_digest: digest(token), purpose: purpose.to_s)
  end

  # The subject's current usable token for a purpose, if any.
  # @return [OneTimeToken, nil]
  def self.current_for(subject, purpose:)
    usable.where(subject: subject, purpose: purpose.to_s).order(created_at: :desc).first
  end

  # Checks a code, counting wrong guesses. Once `max_attempts` are used up the token is dead.
  # @param code [String]
  # @param max_attempts [Integer]
  # @return [Boolean]
  def code_matches?(code, max_attempts:)
    return false if code_digest.blank? || failed_attempts >= max_attempts

    return true if ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.code_digest(code))

    self.class.where(id: id).update_all("failed_attempts = failed_attempts + 1")
    false
  end

  # Marks the token consumed. Safe against concurrent use: only one caller can succeed.
  # @return [Boolean] false when the token was already consumed
  def consume!
    self.class.where(id: id, consumed_at: nil).update_all(consumed_at: Time.current) == 1
  end
end
