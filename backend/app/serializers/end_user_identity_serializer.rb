class EndUserIdentitySerializer
  include Alba::Resource

  attributes :uid, :subject, :email, :last_sign_in_at, :created_at
  attribute(:identity_provider_uid) { |identity| identity.identity_provider.uid }
  attribute(:identity_provider_kind) { |identity| identity.identity_provider.kind }
  attribute(:identity_provider_name) { |identity| identity.identity_provider.name }
end
