module IdentityProviders
  class CreateRequest < ApplicationRequestModel
    attribute :kind, RequestTypes::T::String.enum(*IdentityProvider.kinds.values)
      .meta(description: "google, apple, or oidc for any other OpenID Connect provider.")
    attribute :name, RequestTypes::Name.meta(description: "Shown to end users, e.g. on sign-in buttons.")
    attribute :client_id, RequestTypes::ProviderClientId
    attribute? :client_secret, RequestTypes::T::String.constrained(min_size: 1, max_size: 1000)
      .meta(description: "Google and OIDC only. Write-only.")
    attribute? :additional_audiences, RequestTypes::ProviderAudiences
    attribute? :scopes, RequestTypes::ProviderScopes
    attribute? :discovery_url, RequestTypes::ProviderDiscoveryUrl
    attribute? :apple_team_id, RequestTypes::AppleId
    attribute? :apple_key_id, RequestTypes::AppleId
    attribute? :apple_private_key, RequestTypes::T::String.constrained(min_size: 1, max_size: 4000)
      .meta(description: "Apple only: the .p8 key's contents, in PEM format. Write-only.")
    attribute? :enabled, RequestTypes::T::Bool
  end
end
