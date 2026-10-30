module IdentityProviders
  class CreateRequest < ApplicationRequestModel
    attribute :kind, Fields::Kind
    attribute :name, Fields::Name
    attribute? :client_id, Fields::ClientId
    attribute? :client_secret, Fields::ClientSecret
    attribute? :additional_audiences, Fields::AdditionalAudiences
    attribute? :scopes, Fields::Scopes
    attribute? :discovery_url, Fields::DiscoveryUrl
    attribute? :apple_team_id, Fields::AppleTeamId
    attribute? :apple_key_id, Fields::AppleKeyId
    attribute? :apple_private_key, Fields::ApplePrivateKey
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
  end
end
