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
    attribute? :enabled, RequestTypes::T::Bool
  end
end
