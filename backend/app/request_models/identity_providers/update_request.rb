module IdentityProviders
  # The kind can't change. Leave secrets out, or blank, to keep the current ones.
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, Fields::Name
    attribute? :client_id, Fields::ClientId
    attribute? :client_secret, Fields::ReplacementClientSecret
    attribute? :additional_audiences, Fields::AdditionalAudiences
    attribute? :scopes, Fields::Scopes
    attribute? :discovery_url, Fields::DiscoveryUrl
    attribute? :apple_team_id, Fields::AppleTeamId
    attribute? :apple_key_id, Fields::AppleKeyId
    attribute? :apple_private_key, Fields::ReplacementApplePrivateKey
    attribute? :saml_idp_entity_id, Fields::SamlIdpEntityId
    attribute? :saml_sso_url, Fields::SamlSsoUrl
    attribute? :saml_slo_url, Fields::SamlSloUrl
    attribute? :saml_idp_certificates, Fields::SamlIdpCertificates
    attribute? :saml_name_id_format, Fields::SamlNameIdFormat
    attribute? :saml_email_attribute, Fields::SamlEmailAttribute
    attribute? :saml_name_attribute, Fields::SamlNameAttribute
    attribute? :saml_groups_attribute, Fields::SamlGroupsAttribute
    attribute? :domains, Fields::Domains
    attribute? :create_users, Fields::CreateUsers
    attribute? :allow_idp_initiated, Fields::AllowIdpInitiated
    attribute? :group_mappings, Fields::GroupMappings
    attribute? :enabled, Fields::Enabled
    attribute? :on_custom_domain, RequestTypes::T::Bool
      .meta(description: "SAML only: use the project's verified custom domain for the service provider's entity ID and URLs. Send the new metadata to the identity provider's admin after switching.")
  end
end
