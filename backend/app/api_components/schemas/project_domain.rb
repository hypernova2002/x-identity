class Schemas::ProjectDomain
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid hostname status verified_at last_checked_at check_error dns_missing_since certificate_status verify_until created_at saml_apps saml_identity_providers dns_records],
    properties: {
      uid: { type: :string },
      hostname: { type: :string },
      status: { type: :string, enum: %w[pending verified failed] },
      verified_at: { type: [ :string, :null ], format: "date-time" },
      last_checked_at: { type: [ :string, :null ], format: "date-time" },
      check_error: { type: [ :string, :null ], description: "What the last DNS check found wrong." },
      dns_missing_since: { type: [ :string, :null ], format: "date-time", description: "Since when a verified domain's DNS records have been missing." },
      certificate_status: { type: :string, enum: %w[external], description: "external: TLS certificates are issued outside x-identity." },
      verify_until: { type: :string, format: "date-time", description: "When a pending domain stops being checked and fails." },
      created_at: { type: :string, format: "date-time" },
      saml_apps: { type: :array, description: "The project's SAML apps, and whether each uses the custom domain.", items: Schemas::SamlConnection },
      saml_identity_providers: {
        type: :array, description: "The project's SAML identity providers, and whether each uses the custom domain.", items: Schemas::SamlConnection
      },
      dns_records: {
        type: :array,
        description: "The records to create at the domain's DNS provider.",
        items: {
          type: :object,
          required: %w[type name value],
          properties: { type: { type: :string, enum: %w[CNAME TXT] }, name: { type: :string }, value: { type: :string } }
        }
      }
    }
  )
end
