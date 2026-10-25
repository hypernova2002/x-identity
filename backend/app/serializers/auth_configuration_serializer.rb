class AuthConfigurationSerializer
  include Alba::Resource

  ATTRIBUTES = %i[
    mfa_requirement
    require_email_verification
    notify_new_devices
    passkeys
    password_min_length
    password_require_uppercase
    password_require_lowercase
    password_require_number
    password_require_symbol
    password_max_age_seconds
    lockout_threshold
    lockout_window_seconds
    lockout_duration_seconds
    access_token_ttl_seconds
    refresh_token_ttl_seconds
    session_idle_timeout_seconds
    sso_session_ttl_seconds
    signing_algorithm
    signing_key_rotation_seconds
    mfa_max_failed_attempts
    email_code_max_attempts
    email_code_max_failures_per_email
    email_code_max_failures_per_code
    email_code_failure_window_seconds
    otp_method
    otp_digits
    otp_step_seconds
    otp_drift_steps
    otp_hotp_look_ahead
    client_secret_rotation_overlap_seconds
    token_requests_per_minute
  ].freeze

  attributes(*ATTRIBUTES, :updated_at)
end
