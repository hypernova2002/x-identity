class Schemas::AppClient
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name client_type allowed_origins redirect_uris post_logout_redirect_uris launch_url enabled created_at updated_at],
    properties: {
      uid: { type: :string, example: "cl_4Kd8Wq2LmP7xR5tN9vB3cZ6h", description: "Sent as `client_id` by the app." },
      name: { type: :string },
      client_type: { type: :string, enum: AppClient.client_types.values },
      allowed_origins: { type: :array, items: { type: :string } },
      redirect_uris: { type: :array, items: { type: :string } },
      post_logout_redirect_uris: { type: :array, items: { type: :string } },
      launch_url: { type: [ :string, :null ], description: "Where the app portal opens the app." },
      enabled: { type: :boolean },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
