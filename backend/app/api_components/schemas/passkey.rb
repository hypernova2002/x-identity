class Schemas::Passkey
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name created_at last_used_at domain synced],
    properties: {
      uid: { type: :string },
      name: { type: :string },
      created_at: { type: :string, format: "date-time" },
      last_used_at: { type: [ :string, :null ], format: "date-time" },
      domain: { type: :string, description: "The domain the passkey belongs to; it only works there." },
      synced: { type: :boolean, description: "Saved in a password manager that syncs it across devices, rather than kept on one device or security key." }
    }
  )
end
