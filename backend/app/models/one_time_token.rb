# A single-use, expiring token sent to a user (email links) or held briefly by a client (sign-in challenges).
# Only a digest is stored; the plaintext is returned once by {.issue!}.
class OneTimeToken < ApplicationRecord
  TTLS = {
    "email_verification" => 24.hours,
    "password_reset" => 1.hour,
    "email_change" => 1.hour,
    "sign_in_challenge" => 5.minutes
  }.freeze

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

  # Issues a token, invalidating the subject's earlier unused tokens with the same purpose.
  # @param subject [ApplicationRecord]
  # @param purpose [String, Symbol]
  # @param data [Hash]
  # @return [Array(OneTimeToken, String)] the record and its plaintext token
  def self.issue!(subject:, purpose:, data: {})
    purpose = purpose.to_s
    token = SecureRandom.base58(32)

    record = transaction do
      usable.where(subject: subject, purpose: purpose).update_all(consumed_at: Time.current)
      create!(subject: subject, purpose: purpose, data: data, token_digest: digest(token), expires_at: TTLS.fetch(purpose).from_now)
    end

    [ record, token ]
  end

  # @param token [String]
  # @param purpose [String, Symbol]
  # @return [OneTimeToken, nil]
  def self.find_usable(token, purpose:)
    usable.find_by(token_digest: digest(token), purpose: purpose.to_s)
  end

  # Marks the token consumed. Safe against concurrent use: only one caller can succeed.
  # @return [Boolean] false when the token was already consumed
  def consume!
    self.class.where(id: id, consumed_at: nil).update_all(consumed_at: Time.current) == 1
  end
end
