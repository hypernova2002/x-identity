# A one-time-password secret: time-based (TOTP, authenticator apps) or counter-based (HOTP, mostly
# hardware tokens). Each credential keeps the digits and step length it was enrolled with, so
# changing the settings later doesn't break existing authenticators. Unconfirmed until the user
# proves their app or token produces valid codes.
class OtpCredential < ApplicationRecord
  ISSUER = "x-identity".freeze

  belongs_to :subject, polymorphic: true

  enum :otp_type, { totp: "totp", hotp: "hotp" }, validate: true, prefix: true

  encrypts :secret

  validates :secret, presence: true
  validates :subject_id, uniqueness: { scope: :subject_type }
  validates :digits, numericality: { only_integer: true, in: AuthConfiguration::OTP_DIGITS }
  validates :step_seconds, numericality: { only_integer: true, in: AuthConfiguration::OTP_STEP_SECONDS }
  validates :counter, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :confirmed, -> { where.not(confirmed_at: nil) }

  # @param subject [User, EndUser]
  # @param otp_type [String] "totp" or "hotp"
  # @param digits [Integer]
  # @param step_seconds [Integer] TOTP only
  # @return [OtpCredential] an unsaved credential with a fresh random secret
  def self.generate(subject:, otp_type: "totp", digits: 6, step_seconds: 30)
    new(subject: subject, secret: ROTP::Base32.random, otp_type: otp_type, digits: digits, step_seconds: step_seconds)
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
    issuer = "#{ISSUER} (#{account_name})"
    return hotp(issuer: issuer).provisioning_uri(label, counter) if otp_type_hotp?

    totp(issuer: issuer).provisioning_uri(label)
  end

  # Verifies a code. A code is never accepted twice: TOTP refuses codes from the last accepted time
  # step or earlier, and HOTP moves the counter past every accepted code.
  # @param code [String]
  # @param drift_steps [Integer] TOTP: time steps accepted either side of now
  # @param look_ahead [Integer] HOTP: how many counter values ahead to search
  # @return [Boolean]
  def verify(code, drift_steps:, look_ahead:)
    code = code.to_s.gsub(/\s/, "")
    otp_type_hotp? ? verify_hotp(code, look_ahead) : verify_totp(code, drift_steps)
  end

  private

  def totp(issuer: nil)
    ROTP::TOTP.new(secret, digits: digits, interval: step_seconds, issuer: issuer)
  end

  def hotp(issuer: nil)
    ROTP::HOTP.new(secret, digits: digits, issuer: issuer)
  end

  def verify_totp(code, drift_steps)
    drift = drift_steps * step_seconds
    timestamp = totp.verify(code, drift_behind: drift, drift_ahead: drift, after: last_verified_timestamp)
    return false if timestamp.nil?

    self.class.where(id: id).where("last_verified_timestamp IS NULL OR last_verified_timestamp < ?", timestamp)
      .update_all(last_verified_timestamp: timestamp) == 1
  end

  def verify_hotp(code, look_ahead)
    matched = hotp.verify(code, counter, retries: look_ahead - 1)
    return false if matched.nil?

    self.class.where(id: id, counter: counter).update_all(counter: matched + 1) == 1
  end
end
