class Schemas::ApiResource
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name identifier scopes access_token_ttl_seconds app_count created_at updated_at],
    properties: {
      uid: { type: :string, example: "api_8Hd2Lq6Wm3Xc9Vb5Nz7Rt4Kj" },
      name: { type: :string },
      identifier: { type: :string, description: "The `aud` of access tokens for this API." },
      scopes: {
        type: :array,
        items: { type: :object, required: %w[name description], properties: { name: { type: :string }, description: { type: [ :string, :null ] } } }
      },
      access_token_ttl_seconds: { type: [ :integer, :null ], description: "Null uses the project's access token lifetime." },
      app_count: { type: :integer, description: "Machine-to-machine apps with access." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
