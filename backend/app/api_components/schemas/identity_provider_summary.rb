class Schemas::IdentityProviderSummary
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid kind name],
    properties: {
      uid: { type: :string, example: "idp_7Gq2Lm9Xc4Vb8Nz3Rt6Wk5Jh" },
      kind: { type: :string, enum: IdentityProvider.kinds.values },
      name: { type: :string }
    }
  )
end
