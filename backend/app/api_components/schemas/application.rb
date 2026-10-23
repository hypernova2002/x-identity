class Schemas::Application
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[app_type uid name enabled client_type entity_id created_at],
    properties: {
      app_type: { type: :string, enum: %w[app_client saml_app] },
      uid: { type: :string },
      name: { type: :string },
      enabled: { type: :boolean },
      client_type: { type: [ :string, :null ], enum: [ "public", "confidential", nil ], description: "App clients only." },
      entity_id: { type: [ :string, :null ], description: "SAML apps only." },
      created_at: { type: :string, format: "date-time" }
    }
  )
end
