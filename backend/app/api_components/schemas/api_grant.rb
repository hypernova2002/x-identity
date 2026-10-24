class Schemas::ApiGrant
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid api_uid api_name api_identifier scopes created_at updated_at],
    properties: {
      uid: { type: :string },
      api_uid: { type: :string },
      api_name: { type: :string },
      api_identifier: { type: :string },
      scopes: { type: :array, items: { type: :string }, description: "What the app may request in tokens for the API." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
