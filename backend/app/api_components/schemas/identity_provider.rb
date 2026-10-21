class Schemas::IdentityProvider
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid kind name enabled client_id client_secret_set additional_audiences scopes discovery_url issuer
      apple_team_id apple_key_id apple_private_key_set callback_url created_at updated_at],
    properties: {
      uid: { type: :string, example: "idp_7Gq2Lm9Xc4Vb8Nz3Rt6Wk5Jh" },
      kind: { type: :string, enum: IdentityProvider.kinds.values },
      name: { type: :string },
      enabled: { type: :boolean },
      client_id: { type: :string },
      client_secret_set: { type: :boolean, description: "Secrets are write-only." },
      additional_audiences: { type: :array, items: { type: :string } },
      scopes: { type: :string, description: "Not used for Apple, which always asks for name and email." },
      discovery_url: { type: [ :string, :null ] },
      issuer: { type: [ :string, :null ], description: "The `iss` the provider's ID tokens carry." },
      apple_team_id: { type: [ :string, :null ] },
      apple_key_id: { type: [ :string, :null ] },
      apple_private_key_set: { type: :boolean },
      callback_url: { type: :string, description: "Register this as the redirect URI with the provider." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
