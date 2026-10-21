# A partial update: only the settings sent are changed. Durations are in seconds.
module AuthConfigurations
  class UpdateRequest < ApplicationRequestModel
    T = RequestTypes::T

    def self.seconds(attribute, description)
      range = AuthConfiguration::DURATION_RANGES.fetch(attribute)
      type = T::Integer.constrained(gteq: range.min, lteq: range.max)
      type = type.optional if AuthConfiguration::OPTIONAL_DURATIONS.include?(attribute)
      type.meta(description: "#{description} In seconds, #{range.min}–#{range.max}.")
    end

    attribute? :mfa_requirement, T::String.enum(*AuthConfiguration.mfa_requirements.keys)
    attribute? :require_email_verification, T::Bool
    attribute? :password_min_length, T::Integer.constrained(gteq: 8, lteq: AuthConfiguration::PASSWORD_MAX_LENGTH)
    attribute? :password_require_uppercase, T::Bool
    attribute? :password_require_lowercase, T::Bool
    attribute? :password_require_number, T::Bool
    attribute? :password_require_symbol, T::Bool
    attribute? :password_max_age_seconds, seconds(:password_max_age_seconds, "How long a password lasts; null means forever.")
    attribute? :lockout_threshold, T::Integer.constrained(gteq: 3, lteq: 100)
    attribute? :lockout_window_seconds, seconds(:lockout_window_seconds, "Period in which failed sign-ins are counted.")
    attribute? :lockout_duration_seconds, seconds(:lockout_duration_seconds, "How long an email stays locked.")
    attribute? :access_token_ttl_seconds, seconds(:access_token_ttl_seconds, "Access token lifetime.")
    attribute? :refresh_token_ttl_seconds, seconds(:refresh_token_ttl_seconds, "Session lifetime from sign-in.")
    attribute? :session_idle_timeout_seconds, seconds(:session_idle_timeout_seconds, "Unused sessions end after this; null means never.")
    attribute? :signing_algorithm, T::String.enum(*SigningKey::ALGORITHMS)
    attribute? :signing_key_rotation_seconds, seconds(:signing_key_rotation_seconds, "How often signing keys are replaced.")
    attribute? :mfa_max_failed_attempts, T::Integer.constrained(gteq: 3, lteq: 20)
      .meta(description: "Consecutive wrong one-time or recovery codes before the user is disabled.")
    attribute? :email_code_max_attempts, T::Integer.constrained(gteq: 3, lteq: 10)
      .meta(description: "Wrong guesses before a single email code stops working.")
    attribute? :email_code_max_failures_per_email, T::Integer.constrained(gteq: 3, lteq: 100)
      .meta(description: "Wrong email codes per address, across all codes, within the failure window.")
    attribute? :email_code_max_failures_per_code, T::Integer.constrained(gteq: 2, lteq: 100)
      .meta(description: "Wrong attempts with the same code value, across all addresses, within the failure window.")
    attribute? :otp_methods, T::Array.of(T::String.enum(*AuthConfiguration::OTP_METHODS)).constrained(min_size: 1, max_size: 2)
      .meta(description: "totp for authenticator apps, hotp for hardware tokens. Existing credentials keep working either way.")
    attribute? :otp_digits, T::Integer.constrained(gteq: AuthConfiguration::OTP_DIGITS.min, lteq: AuthConfiguration::OTP_DIGITS.max)
      .meta(description: "Code length for new credentials. Most authenticator apps only support 6.")
    attribute? :otp_step_seconds, T::Integer.constrained(gteq: AuthConfiguration::OTP_STEP_SECONDS.min, lteq: AuthConfiguration::OTP_STEP_SECONDS.max)
      .meta(description: "TOTP step length for new credentials, in seconds. Most authenticator apps only support 30.")
    attribute? :otp_drift_steps, T::Integer.constrained(gteq: 0, lteq: 2)
      .meta(description: "TOTP steps accepted either side of the current one, for clock differences.")
    attribute? :otp_hotp_look_ahead, T::Integer.constrained(gteq: 1, lteq: 20)
      .meta(description: "HOTP counter values searched ahead, for tokens pressed without signing in.")
    attribute? :email_code_failure_window_seconds, seconds(:email_code_failure_window_seconds, "Period in which wrong email codes are counted.")
  end
end
