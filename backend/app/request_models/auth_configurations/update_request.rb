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
      .meta(description: "off, optional (users can turn MFA on) or required (users must set up MFA when they next sign in).")
    attribute? :require_email_verification, T::Bool.meta(description: "Users must confirm their email address before they can sign in.")
    attribute? :notify_new_devices, T::Bool
      .meta(description: "Email users when they sign in from a device and country they haven't used in 90 days.")
    attribute? :passwordless_after_passkey, T::Bool
      .meta(description: "Users who have a passkey that works where they sign in can't sign in with a password there. Resetting the password by email lets them in to add a new passkey. Needs passkeys on.")
    attribute? :passkeys, T::String.enum(*AuthConfiguration.passkeys.keys)
      .meta(description: "off, optional (users can add passkeys and sign in with them) or required (sign-ins must use a passkey wherever passkeys work, and require MFA elsewhere). Projects need a verified custom domain; required needs MFA not off.")
    attribute? :password_min_length, T::Integer.constrained(gteq: 8, lteq: AuthConfiguration::PASSWORD_MAX_LENGTH)
      .meta(description: "The shortest password allowed, 8–#{AuthConfiguration::PASSWORD_MAX_LENGTH} characters.")
    attribute? :password_require_uppercase, T::Bool.meta(description: "Passwords must contain an uppercase letter.")
    attribute? :password_require_lowercase, T::Bool.meta(description: "Passwords must contain a lowercase letter.")
    attribute? :password_require_number, T::Bool.meta(description: "Passwords must contain a number.")
    attribute? :password_require_symbol, T::Bool.meta(description: "Passwords must contain a symbol.")
    attribute? :password_max_age_seconds, seconds(:password_max_age_seconds, "How long a password lasts; null means forever.")
    attribute? :lockout_threshold, T::Integer.constrained(gteq: 3, lteq: 100)
      .meta(description: "Failed sign-ins for an email, within the lockout window, before it's locked. 3–100.")
    attribute? :lockout_window_seconds, seconds(:lockout_window_seconds, "Period in which failed sign-ins are counted.")
    attribute? :lockout_duration_seconds, seconds(:lockout_duration_seconds, "How long an email stays locked.")
    attribute? :access_token_ttl_seconds, seconds(:access_token_ttl_seconds, "Access token lifetime.")
    attribute? :refresh_token_ttl_seconds, seconds(:refresh_token_ttl_seconds, "Session lifetime from sign-in.")
    attribute? :session_idle_timeout_seconds, seconds(:session_idle_timeout_seconds, "Unused sessions end after this; null means never.")
    attribute? :sso_session_ttl_seconds, seconds(:sso_session_ttl_seconds, "Projects only: how long a hosted login session signs users in to other apps.")
    attribute? :client_secret_rotation_overlap_seconds,
      seconds(:client_secret_rotation_overlap_seconds, "Projects only: how long a confidential client's previous secrets keep working after it's rotated; 0 stops them at once.")
    attribute? :token_requests_per_minute, RequestTypes::TokenRequestsPerMinute
      .meta(description: "Projects only: token endpoint requests allowed per app client per minute, unless the app sets its own limit.")
    attribute? :signing_algorithm, T::String.enum(*SigningKey::ALGORITHMS)
      .meta(description: "The algorithm new signing keys use: #{SigningKey::ALGORITHMS.join(', ')}.")
    attribute? :signing_key_rotation_seconds, seconds(:signing_key_rotation_seconds, "How often signing keys are replaced.")
    attribute? :mfa_max_failed_attempts, T::Integer.constrained(gteq: 3, lteq: 20)
      .meta(description: "Consecutive wrong one-time or recovery codes before the user is disabled.")
    attribute? :email_code_max_attempts, T::Integer.constrained(gteq: 3, lteq: 10)
      .meta(description: "Wrong guesses before a single email code stops working.")
    attribute? :email_code_max_failures_per_email, T::Integer.constrained(gteq: 3, lteq: 100)
      .meta(description: "Wrong email codes per address, across all codes, within the failure window.")
    attribute? :email_code_max_failures_per_code, T::Integer.constrained(gteq: 2, lteq: 100)
      .meta(description: "Wrong attempts with the same code value, across all addresses, within the failure window.")
    attribute? :otp_method, T::String.enum(*AuthConfiguration::OTP_METHODS)
      .meta(description: "totp for authenticator apps or hotp for hardware tokens, for everyone. Existing credentials keep working.")
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
