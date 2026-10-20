class UserSerializer
  include Alba::Resource

  attributes :uid, :name, :email, :role, :status, :last_sign_in_at, :created_at, :updated_at

  attribute :email_verified, &:email_verified?
  attribute :mfa_enabled, &:mfa_enabled?
end
