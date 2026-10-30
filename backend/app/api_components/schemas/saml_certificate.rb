class Schemas::SamlCertificate
  include OpenapiRuby::Components::Base

  schema(
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
  )
end
