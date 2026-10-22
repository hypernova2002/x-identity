module IdentityProviders
  # The kind can't change. Leave secrets out, or blank, to keep the current ones.
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :client_id, RequestTypes::ProviderClientId
    attribute? :client_secret, RequestTypes::T::String.constrained(max_size: 1000).meta(description: "Write-only.")
    attribute? :additional_audiences, RequestTypes::ProviderAudiences
    attribute? :scopes, RequestTypes::ProviderScopes
    attribute? :discovery_url, RequestTypes::ProviderDiscoveryUrl
    attribute? :apple_team_id, RequestTypes::AppleId
    attribute? :apple_key_id, RequestTypes::AppleId
    attribute? :apple_private_key, RequestTypes::T::String.constrained(max_size: 4000).meta(description: "Write-only.")
    attribute? :saml_idp_entity_id, RequestTypes::T::String.constrained(min_size: 1, max_size: 1024).meta(description: "SAML only: the IdP's entity ID.")
    attribute? :saml_sso_url, RequestTypes::T::String.constrained(min_size: 1, max_size: 2048).meta(description: "SAML only: the IdP's sign-on URL (HTTP-Redirect).")
    attribute? :saml_slo_url, RequestTypes::T::String.constrained(max_size: 2048).optional.meta(description: "SAML only: the IdP's logout URL (HTTP-Redirect).")
    attribute? :saml_idp_certificates, RequestTypes::T::Array.of(RequestTypes::T::String.constrained(min_size: 1, max_size: 10_000))
      .constrained(max_size: IdentityProvider::MAX_CERTIFICATES).meta(description: "SAML only: the IdP's signing certificates (PEM).")
    attribute? :saml_name_id_format, RequestTypes::T::String.enum(*SamlApp::NAME_ID_FORMATS.keys)
    attribute? :saml_email_attribute, RequestTypes::T::String.constrained(max_size: 255).optional
      .meta(description: "SAML only: the attribute with the email; empty uses the NameID.")
    attribute? :saml_name_attribute, RequestTypes::T::String.constrained(max_size: 255).optional
    attribute? :saml_groups_attribute, RequestTypes::T::String.constrained(max_size: 255).optional
    attribute? :domains, RequestTypes::T::Array.of(RequestTypes::T::String.constrained(min_size: 1, max_size: 253)).constrained(max_size: IdentityProvider::MAX_DOMAINS)
      .meta(description: "Email domains the provider is authoritative for. SAML providers only sign in addresses at these domains, and users who enter them are sent to the provider.")
    attribute? :create_users, RequestTypes::T::Bool.meta(description: "Create end users on their first sign-in, even when self sign-up is off.")
    attribute? :allow_idp_initiated, RequestTypes::T::Bool.meta(description: "SAML only: accept sign-ins started from the provider, landing on the app portal.")
    attribute? :group_mappings, RequestTypes::T::Array.of(IdentityProviders::GroupMappingRequest).constrained(max_size: 100)
      .meta(description: "Provider group values mapped to project groups. Replaces the current mappings.")
    attribute? :enabled, RequestTypes::T::Bool
  end
end
