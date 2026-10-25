class Schemas::ApplicationStats
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[total oidc machine saml],
    properties: {
      total: { type: :integer },
      oidc: { type: :integer, description: "OpenID Connect apps that users sign in to." },
      machine: { type: :integer, description: "Machine-to-machine apps (client credentials)." },
      saml: { type: :integer }
    }
  )
end
