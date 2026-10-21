class Schemas::AuthConfiguration
  include OpenapiRuby::Components::Base

  durations = AuthConfiguration::DURATION_RANGES.to_h do |attribute, range|
    type = AuthConfiguration::OPTIONAL_DURATIONS.include?(attribute) ? [ :integer, :null ] : :integer
    [ attribute, { type: type, minimum: range.min, maximum: range.max, description: "Seconds." } ]
  end

  schema(
    type: :object,
    required: AuthConfigurationSerializer::ATTRIBUTES.map(&:to_s) - AuthConfiguration::OPTIONAL_DURATIONS.map(&:to_s),
    properties: {
      mfa_requirement: { type: :string, enum: AuthConfiguration.mfa_requirements.keys },
      require_email_verification: { type: :boolean },
      password_min_length: { type: :integer, minimum: 8, maximum: AuthConfiguration::PASSWORD_MAX_LENGTH },
      password_require_uppercase: { type: :boolean },
      password_require_lowercase: { type: :boolean },
      password_require_number: { type: :boolean },
      password_require_symbol: { type: :boolean },
      lockout_threshold: { type: :integer, minimum: 3, maximum: 100 },
      signing_algorithm: { type: :string, enum: SigningKey::ALGORITHMS },
      mfa_max_failed_attempts: { type: :integer, minimum: 3, maximum: 20 },
      email_code_max_attempts: { type: :integer, minimum: 3, maximum: 10 },
      email_code_max_failures_per_email: { type: :integer, minimum: 3, maximum: 100 },
      email_code_max_failures_per_code: { type: :integer, minimum: 2, maximum: 100 },
      otp_method: { type: :string, enum: AuthConfiguration::OTP_METHODS, description: "The one method everyone in the account or project uses for MFA." },
      otp_digits: { type: :integer, minimum: AuthConfiguration::OTP_DIGITS.min, maximum: AuthConfiguration::OTP_DIGITS.max },
      otp_step_seconds: { type: :integer, minimum: AuthConfiguration::OTP_STEP_SECONDS.min, maximum: AuthConfiguration::OTP_STEP_SECONDS.max },
      otp_drift_steps: { type: :integer, minimum: 0, maximum: 2 },
      otp_hotp_look_ahead: { type: :integer, minimum: 1, maximum: 20 },
      **durations,
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
