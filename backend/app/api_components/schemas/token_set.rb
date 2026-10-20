class Schemas::TokenSet
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[access_token refresh_token token_type expires_in],
    properties: {
      access_token: { type: :string, description: "JWT. Verify with the account's JWKS." },
      refresh_token: { type: :string, description: "Single use. Every refresh returns a new one." },
      token_type: { type: :string, enum: %w[Bearer] },
      expires_in: { type: :integer, description: "Access token lifetime in seconds." },
      recovery_codes: { type: :array, items: { type: :string }, description: "Only after completing MFA setup." }
    }
  )
end
