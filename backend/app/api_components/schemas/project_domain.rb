class Schemas::ProjectDomain
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid hostname status verified_at last_checked_at check_error check_error_params dns_missing_since certificate_status verify_until created_at saml_apps saml_identity_providers passkey_count passkey_related_origins dns_records],
    properties: {
      uid: { type: :string },
      hostname: { type: :string },
      status: { type: :string, enum: %w[pending verified failed] },
      verified_at: { type: [ :string, :null ], format: "date-time" },
      last_checked_at: { type: [ :string, :null ], format: "date-time" },
      check_error: {
        type: [ :string, :null ],
        enum: [ "missing_txt_record", "cname_mismatch", "missing_cname", "unknown", nil ],
        description: "What the last DNS check found wrong, as a code."
      },
      check_error_params: { type: :object, description: "Values the check error refers to: name, hostname, found and target." },
      dns_missing_since: { type: [ :string, :null ], format: "date-time", description: "Since when a verified domain's DNS records have been missing." },
      certificate_status: { type: :string, enum: %w[external], description: "external: TLS certificates are issued outside x-identity." },
      verify_until: { type: :string, format: "date-time", description: "When a pending domain stops being checked and fails." },
      created_at: { type: :string, format: "date-time" },
      saml_apps: { type: :array, description: "The project's SAML apps, and whether each uses the custom domain.", items: Schemas::SamlConnection },
      saml_identity_providers: {
        type: :array, description: "The project's SAML identity providers, and whether each uses the custom domain.", items: Schemas::SamlConnection
      },
      passkey_count: { type: :integer, description: "End users' passkeys that belong to the domain; they stop working if it's removed or replaced." },
      passkey_related_origins: {
        type: :array, items: { type: :string },
        description: "Other origins listed in the domain's /.well-known/webauthn: the project's apps' allowed origins, which can use its passkeys."
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
