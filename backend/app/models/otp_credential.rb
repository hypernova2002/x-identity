# A TOTP secret. Unconfirmed until the user proves their authenticator app produces valid codes.
class OtpCredential < ApplicationRecord
  ISSUER = "x-identity".freeze
  DRIFT_SECONDS = 30

  belongs_to :subject, polymorphic: true

  encrypts :secret

  validates :secret, presence: true
  validates :subject_id, uniqueness: { scope: :subject_type }

  scope :confirmed, -> { where.not(confirmed_at: nil) }

  # @return [OtpCredential] an unsaved credential with a fresh random secret
  def self.generate(subject:)
    new(subject: subject, secret: ROTP::Base32.random)
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current)
  end

  # @param account_name [String] shown next to the code in authenticator apps
  # @param label [String] usually the user's email
  # @return [String] an otpauth:// URI
  def provisioning_uri(account_name:, label:)
    ROTP::TOTP.new(secret, issuer: "#{ISSUER} (#{account_name})").provisioning_uri(label)
  end

  # Verifies a code, refusing reuse of a code from the last accepted time step or earlier.
  # @param code [String]
  # @return [Boolean]
  def verify(code)
    timestamp = ROTP::TOTP.new(secret).verify(
      code.to_s.gsub(/\s/, ""),
      drift_behind: DRIFT_SECONDS,
      drift_ahead: DRIFT_SECONDS,
      after: last_verified_timestamp
    )
    return false if timestamp.nil?

    self.class.where(id: id).where("last_verified_timestamp IS NULL OR last_verified_timestamp < ?", timestamp)
      .update_all(last_verified_timestamp: timestamp) == 1
  end
end
