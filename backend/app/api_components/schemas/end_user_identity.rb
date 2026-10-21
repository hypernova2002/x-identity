class Schemas::EndUserIdentity
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid identity_provider_uid identity_provider_kind identity_provider_name subject email last_sign_in_at created_at],
    properties: {
      uid: { type: :string, example: "eui_3Fh8Kq2Wm7Xn4Bv9Lc6Tz5Rp" },
      identity_provider_uid: { type: :string },
      identity_provider_kind: { type: :string, enum: IdentityProvider.kinds.values },
      identity_provider_name: { type: :string },
      subject: { type: :string, description: "The user's id at the provider (`sub`)." },
      email: { type: [ :string, :null ], description: "The email the provider gave at the last sign-in." },
      last_sign_in_at: { type: [ :string, :null ], format: "date-time" },
      created_at: { type: :string, format: "date-time" }
    }
  )
end
