class AuthConfigurationSerializer
  include Alba::Resource

  ATTRIBUTES = %i[
    mfa_requirement
    require_email_verification
    password_min_length
    password_require_uppercase
    password_require_lowercase
    password_require_number
    password_require_symbol
    password_max_age_days
    lockout_threshold
    lockout_window_minutes
    lockout_duration_minutes
    access_token_ttl_minutes
    refresh_token_ttl_days
    session_idle_timeout_minutes
    signing_algorithm
    signing_key_rotation_days
  ].freeze

  attributes(*ATTRIBUTES, :updated_at)
end
