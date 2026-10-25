# Authentication settings for an owner's users: an Account's console users, or a Project's end users.
# Every duration is stored in seconds.
class AuthConfiguration < ApplicationRecord
  PASSWORD_MAX_LENGTH = 128
  MAX_ACCESS_TOKEN_TTL_SECONDS = 1.hour.to_i
  OTP_METHODS = %w[totp hotp].freeze
  # OTP codes come from a 31-bit number (RFC 4226), so digits beyond 10 add no strength.
  OTP_DIGITS = 6..10
  OTP_STEP_SECONDS = 30..900
  TOKEN_REQUESTS_PER_MINUTE = 10..10_000

  DURATION_RANGES = {
    password_max_age_seconds: 1.day.to_i..365.days.to_i,
    lockout_window_seconds: 1.minute.to_i..1.day.to_i,
    lockout_duration_seconds: 1.minute.to_i..1.day.to_i,
    access_token_ttl_seconds: 5.minutes.to_i..MAX_ACCESS_TOKEN_TTL_SECONDS,
    refresh_token_ttl_seconds: 1.day.to_i..365.days.to_i,
    session_idle_timeout_seconds: 5.minutes.to_i..30.days.to_i,
    signing_key_rotation_seconds: 30.days.to_i..365.days.to_i,
    email_code_failure_window_seconds: 5.minutes.to_i..1.day.to_i,
    sso_session_ttl_seconds: 5.minutes.to_i..30.days.to_i,
    client_secret_rotation_overlap_seconds: 0..30.days.to_i
  }.freeze
  OPTIONAL_DURATIONS = %i[password_max_age_seconds session_idle_timeout_seconds].freeze

  belongs_to :owner, polymorphic: true

  enum :mfa_requirement, { off: "off", optional: "optional", required: "required" }, prefix: :mfa, validate: true
  # Whether users can add and sign in with passkeys, or must use one wherever passkeys work. A
  # project's also need its verified custom domain.
  enum :passkeys, { off: "off", optional: "optional", required: "required" }, prefix: true, validate: true

  attribute :mfa_requirement, default: "optional"
  attribute :passkeys, default: "off"
  attribute :require_email_verification, default: false
  attribute :notify_new_devices, default: true
  attribute :password_min_length, default: 12
  attribute :password_require_uppercase, default: false
  attribute :password_require_lowercase, default: false
  attribute :password_require_number, default: false
  attribute :password_require_symbol, default: false
  attribute :lockout_threshold, default: 10
  attribute :lockout_window_seconds, default: 15.minutes.to_i
  attribute :lockout_duration_seconds, default: 15.minutes.to_i
  attribute :access_token_ttl_seconds, default: 15.minutes.to_i
  attribute :refresh_token_ttl_seconds, default: 30.days.to_i
  attribute :signing_algorithm, default: "ES256"
  attribute :signing_key_rotation_seconds, default: 90.days.to_i
  attribute :mfa_max_failed_attempts, default: 5
  attribute :email_code_max_attempts, default: 5
  attribute :email_code_max_failures_per_email, default: 10
  attribute :email_code_max_failures_per_code, default: 5
  attribute :email_code_failure_window_seconds, default: 1.hour.to_i
  attribute :otp_method, default: "totp"
  attribute :otp_digits, default: 6
  attribute :otp_step_seconds, default: 30
  attribute :otp_drift_steps, default: 1
  attribute :otp_hotp_look_ahead, default: 10
  attribute :client_secret_rotation_overlap_seconds, default: 7.days.to_i
  attribute :token_requests_per_minute, default: 120

  validates :owner_id, uniqueness: { scope: :owner_type }
  validates :require_email_verification, :notify_new_devices,
    :password_require_uppercase, :password_require_lowercase, :password_require_number, :password_require_symbol,
    inclusion: { in: [ true, false ] }
  validates :password_min_length, numericality: { only_integer: true, in: 8..PASSWORD_MAX_LENGTH }
  validates :lockout_threshold, numericality: { only_integer: true, in: 3..100 }
  validates :signing_algorithm, inclusion: { in: SigningKey::ALGORITHMS }
  validates :mfa_max_failed_attempts, numericality: { only_integer: true, in: 3..20 }
  validates :token_requests_per_minute, numericality: { only_integer: true, in: TOKEN_REQUESTS_PER_MINUTE }
  validates :email_code_max_attempts, numericality: { only_integer: true, in: 3..10 }
  validates :email_code_max_failures_per_email, numericality: { only_integer: true, in: 3..100 }
  validates :email_code_max_failures_per_code, numericality: { only_integer: true, in: 2..100 }
  validates :otp_digits, numericality: { only_integer: true, in: OTP_DIGITS }
  validates :otp_step_seconds, numericality: { only_integer: true, in: OTP_STEP_SECONDS }
  validates :otp_drift_steps, numericality: { only_integer: true, in: 0..2 }
  validates :otp_hotp_look_ahead, numericality: { only_integer: true, in: 1..20 }
  validates :otp_method, inclusion: { in: OTP_METHODS, message: "must be totp or hotp" }
  DURATION_RANGES.each do |attribute, range|
    validates attribute, numericality: { only_integer: true, in: range }, allow_nil: OPTIONAL_DURATIONS.include?(attribute)
  end
  validate :passkeys_can_be_required, if: -> { passkeys_required? && (will_save_change_to_passkeys? || will_save_change_to_mfa_requirement?) }

  # @return [Boolean] whether users can add passkeys and sign in with them
  def passkeys_enabled?
    !passkeys_off?
  end

  # @return [ActiveSupport::Duration]
  def access_token_ttl
    access_token_ttl_seconds.seconds
  end

  # @return [ActiveSupport::Duration]
  def refresh_token_ttl
    refresh_token_ttl_seconds.seconds
  end

  # @return [ActiveSupport::Duration, nil]
  def session_idle_timeout
    session_idle_timeout_seconds&.seconds
  end

  # @return [ActiveSupport::Duration]
  def lockout_window
    lockout_window_seconds.seconds
  end

  # @return [ActiveSupport::Duration]
  def lockout_duration
    lockout_duration_seconds.seconds
  end

  # @return [ActiveSupport::Duration, nil]
  def password_max_age
    password_max_age_seconds&.seconds
  end

  # @return [ActiveSupport::Duration]
  def signing_key_rotation
    signing_key_rotation_seconds.seconds
  end

  # @return [ActiveSupport::Duration]
  def email_code_failure_window
    email_code_failure_window_seconds.seconds
  end

  # Checks a candidate password against this configuration's password rules.
  # @param password [String, nil]
  # @return [Array<String>] human-readable violations; empty when the password is acceptable
  def password_violations(password)
    password = password.to_s
    violations = []
    violations << "must be at least #{password_min_length} characters" if password.length < password_min_length
    violations << "must be at most #{PASSWORD_MAX_LENGTH} characters" if password.length > PASSWORD_MAX_LENGTH
    violations << "must include an uppercase letter" if password_require_uppercase && !password.match?(/[[:upper:]]/)
    violations << "must include a lowercase letter" if password_require_lowercase && !password.match?(/[[:lower:]]/)
    violations << "must include a number" if password_require_number && !password.match?(/\d/)
    violations << "must include a symbol" if password_require_symbol && !password.match?(/[^[:alnum:]]/)
    violations
  end

  private

  # Sign-ins where a passkey can't be used fall back to requiring MFA, so MFA can't be off; a
  # project's passkeys need its custom domain.
  def passkeys_can_be_required
    errors.add(:passkeys, "can't be required while MFA is off, since sign-ins where passkeys can't be used then require MFA") if mfa_off?
    return unless owner.is_a?(Project) && !owner.domains.status_verified.exists?

    errors.add(:passkeys, "can only be required once the project has a verified custom domain")
  end
end
