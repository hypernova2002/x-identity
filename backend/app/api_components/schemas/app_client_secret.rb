class Schemas::AppClientSecret
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid last_four expires_at revoked_at last_used_at created_at usable],
    properties: {
      uid: { type: :string },
      last_four: { type: [ :string, :null ], description: "The secret's last four characters, to tell secrets apart. Null for secrets from before rotation overlap." },
      expires_at: { type: [ :string, :null ], format: "date-time", description: "Set when a newer secret replaces this one." },
      revoked_at: { type: [ :string, :null ], format: "date-time" },
      last_used_at: { type: [ :string, :null ], format: "date-time" },
      created_at: { type: :string, format: "date-time" },
      usable: { type: :boolean }
    }
  )
end
