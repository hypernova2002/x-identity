class Schemas::OauthError
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[error error_description],
    properties: {
      error: { type: :string, description: "The OAuth 2.0 error code, e.g. invalid_grant or invalid_client." },
      error_description: { type: :string }
    }
  )
end
