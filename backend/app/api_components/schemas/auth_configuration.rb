class Schemas::AuthConfiguration
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: AuthConfigurationSerializer::ATTRIBUTES.map(&:to_s) - %w[password_max_age_days session_idle_timeout_minutes],
    properties: {
      mfa_requirement: { type: :string, enum: AuthConfiguration.mfa_requirements.keys },
      require_email_verification: { type: :boolean },
      password_min_length: { type: :integer, minimum: 8, maximum: AuthConfiguration::PASSWORD_MAX_LENGTH },
      password_require_uppercase: { type: :boolean },
      password_require_lowercase: { type: :boolean },
      password_require_number: { type: :boolean },
      password_require_symbol: { type: :boolean },
      password_max_age_days: { type: [ :integer, :null ], minimum: 1, maximum: 365 },
      lockout_threshold: { type: :integer, minimum: 3, maximum: 100 },
      lockout_window_minutes: { type: :integer, minimum: 1, maximum: 1440 },
      lockout_duration_minutes: { type: :integer, minimum: 1, maximum: 1440 },
      access_token_ttl_minutes: { type: :integer, minimum: 5, maximum: AuthConfiguration::MAX_ACCESS_TOKEN_TTL_MINUTES },
      refresh_token_ttl_days: { type: :integer, minimum: 1, maximum: 365 },
      session_idle_timeout_minutes: { type: [ :integer, :null ], minimum: 5, maximum: 43_200 },
      signing_algorithm: { type: :string, enum: SigningKey::ALGORITHMS },
      signing_key_rotation_days: { type: :integer, minimum: 30, maximum: 365 },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
