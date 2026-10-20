# Authentication settings for an owner's users: an Account's console users, and later a Project's end users.
class AuthConfiguration < ApplicationRecord
  PASSWORD_MAX_LENGTH = 128
  MAX_ACCESS_TOKEN_TTL_MINUTES = 60

  belongs_to :owner, polymorphic: true

  enum :mfa_requirement, { off: "off", optional: "optional", required: "required" }, prefix: :mfa, validate: true

  attribute :mfa_requirement, default: "optional"
  attribute :require_email_verification, default: false
  attribute :password_min_length, default: 12
  attribute :password_require_uppercase, default: false
  attribute :password_require_lowercase, default: false
  attribute :password_require_number, default: false
  attribute :password_require_symbol, default: false
  attribute :lockout_threshold, default: 10
  attribute :lockout_window_minutes, default: 15
  attribute :lockout_duration_minutes, default: 15
  attribute :access_token_ttl_minutes, default: 15
  attribute :refresh_token_ttl_days, default: 30
  attribute :signing_algorithm, default: "ES256"
  attribute :signing_key_rotation_days, default: 90

  validates :owner_id, uniqueness: { scope: :owner_type }
  validates :require_email_verification,
    :password_require_uppercase, :password_require_lowercase, :password_require_number, :password_require_symbol,
    inclusion: { in: [ true, false ] }
  validates :password_min_length, numericality: { only_integer: true, in: 8..PASSWORD_MAX_LENGTH }
  validates :password_max_age_days, numericality: { only_integer: true, in: 1..365 }, allow_nil: true
  validates :lockout_threshold, numericality: { only_integer: true, in: 3..100 }
  validates :lockout_window_minutes, :lockout_duration_minutes, numericality: { only_integer: true, in: 1..1440 }
  validates :access_token_ttl_minutes, numericality: { only_integer: true, in: 5..MAX_ACCESS_TOKEN_TTL_MINUTES }
  validates :refresh_token_ttl_days, numericality: { only_integer: true, in: 1..365 }
  validates :session_idle_timeout_minutes, numericality: { only_integer: true, in: 5..43_200 }, allow_nil: true
  validates :signing_algorithm, inclusion: { in: SigningKey::ALGORITHMS }
  validates :signing_key_rotation_days, numericality: { only_integer: true, in: 30..365 }

  # @return [ActiveSupport::Duration]
  def access_token_ttl
    access_token_ttl_minutes.minutes
  end

  # @return [ActiveSupport::Duration]
  def refresh_token_ttl
    refresh_token_ttl_days.days
  end

  # @return [ActiveSupport::Duration, nil]
  def session_idle_timeout
    session_idle_timeout_minutes&.minutes
  end

  # @return [ActiveSupport::Duration]
  def lockout_window
    lockout_window_minutes.minutes
  end

  # @return [ActiveSupport::Duration]
  def lockout_duration
    lockout_duration_minutes.minutes
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
end
