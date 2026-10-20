# A partial update: only the settings sent are changed. Ranges are validated by AuthConfiguration.
class AuthConfigurationRequest < ApplicationRequest
  attribute? :mfa_requirement, JsonModel::Types::String.enum(*AuthConfiguration.mfa_requirements.keys)
  attribute? :require_email_verification, JsonModel::Types::Bool
  attribute? :password_min_length, JsonModel::Types::Integer
  attribute? :password_require_uppercase, JsonModel::Types::Bool
  attribute? :password_require_lowercase, JsonModel::Types::Bool
  attribute? :password_require_number, JsonModel::Types::Bool
  attribute? :password_require_symbol, JsonModel::Types::Bool
  attribute? :password_max_age_days, JsonModel::Types::Integer.optional
  attribute? :lockout_threshold, JsonModel::Types::Integer
  attribute? :lockout_window_minutes, JsonModel::Types::Integer
  attribute? :lockout_duration_minutes, JsonModel::Types::Integer
  attribute? :access_token_ttl_minutes, JsonModel::Types::Integer
  attribute? :refresh_token_ttl_days, JsonModel::Types::Integer
  attribute? :session_idle_timeout_minutes, JsonModel::Types::Integer.optional
  attribute? :signing_algorithm, JsonModel::Types::String.enum(*SigningKey::ALGORITHMS)
  attribute? :signing_key_rotation_days, JsonModel::Types::Integer
end
