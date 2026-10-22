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
      certificates: {
        type: :array,
        items: {
          type: :object,
          required: %w[uid status certificate fingerprint_sha256 activated_at expires_at created_at],
          properties: {
            uid: { type: :string },
            status: { type: :string, enum: SamlCertificate.statuses.keys },
            certificate: { type: :string, description: "PEM." },
            fingerprint_sha256: { type: :string },
            activated_at: { type: [ :string, :null ], format: "date-time" },
            expires_at: { type: :string, format: "date-time" },
            created_at: { type: :string, format: "date-time" }
          }
        }
      }
    }
  )
end
