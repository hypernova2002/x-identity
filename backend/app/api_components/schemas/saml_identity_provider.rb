class Schemas::SamlIdentityProvider
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[entity_id metadata_url sso_url slo_url certificates],
    properties: {
      entity_id: { type: :string },
      metadata_url: { type: :string },
      sso_url: { type: :string },
      slo_url: { type: :string },
      certificates: { type: :array, items: { "$ref": "#/components/schemas/SamlCertificate" } }
    }
  )
end
