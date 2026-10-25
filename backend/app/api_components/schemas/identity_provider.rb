class Schemas::IdentityProvider
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid kind name enabled client_id client_secret_set additional_audiences scopes discovery_url issuer
      apple_team_id apple_key_id apple_private_key_set callback_url saml_idp_entity_id saml_sso_url saml_slo_url
      saml_idp_certificates saml_name_id_format saml_email_attribute saml_name_attribute saml_groups_attribute domains
      create_users allow_idp_initiated on_custom_domain sp_entity_id acs_url sp_slo_url group_mappings created_at updated_at],
    properties: {
      uid: { type: :string, example: "idp_7Gq2Lm9Xc4Vb8Nz3Rt6Wk5Jh" },
      kind: { type: :string, enum: IdentityProvider.kinds.values },
      name: { type: :string },
      enabled: { type: :boolean },
      client_id: { type: [ :string, :null ] },
      client_secret_set: { type: :boolean, description: "Secrets are write-only." },
      additional_audiences: { type: :array, items: { type: :string } },
      scopes: { type: :string, description: "Not used for Apple, which always asks for name and email." },
      discovery_url: { type: [ :string, :null ] },
      issuer: { type: [ :string, :null ], description: "The `iss` the provider's ID tokens carry." },
      apple_team_id: { type: [ :string, :null ] },
      apple_key_id: { type: [ :string, :null ] },
      apple_private_key_set: { type: :boolean },
      callback_url: { type: :string, description: "OIDC providers: register this as the redirect URI with the provider." },
      saml_idp_entity_id: { type: [ :string, :null ] },
      saml_sso_url: { type: [ :string, :null ] },
      saml_slo_url: { type: [ :string, :null ] },
      saml_idp_certificates: { type: :array, items: { type: :string } },
      saml_name_id_format: { type: :string, enum: SamlApp::NAME_ID_FORMATS.keys },
      saml_email_attribute: { type: [ :string, :null ] },
      saml_name_attribute: { type: [ :string, :null ] },
      saml_groups_attribute: { type: [ :string, :null ] },
      domains: { type: :array, items: { type: :string } },
      create_users: { type: :boolean },
      allow_idp_initiated: { type: :boolean },
      on_custom_domain: { type: [ :boolean, :null ], description: "SAML providers: whether the service provider URLs use the project's custom domain." },
      sp_entity_id: { type: [ :string, :null ], description: "SAML providers: the service provider metadata URL and entity ID to give the IdP." },
      acs_url: { type: [ :string, :null ] },
      sp_slo_url: { type: [ :string, :null ] },
      group_mappings: {
        type: :array,
        items: {
          type: :object, required: %w[value group_uid group_name],
          properties: { value: { type: :string }, group_uid: { type: :string }, group_name: { type: :string } }
        }
      },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
