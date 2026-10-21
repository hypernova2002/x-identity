# Secrets are never returned, only whether one is set.
class IdentityProviderSerializer
  include Alba::Resource

  attributes :uid, :kind, :name, :enabled, :client_id, :additional_audiences, :scopes, :discovery_url,
    :apple_team_id, :apple_key_id, :callback_url, :created_at, :updated_at
  attribute(:issuer) { |provider| provider.endpoints["issuer"] }
  attribute(:client_secret_set) { |provider| provider.client_secret.present? }
  attribute(:apple_private_key_set) { |provider| provider.apple_private_key.present? }
end
