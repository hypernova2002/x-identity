class EndUserSerializer
  include Alba::Resource

  attributes :uid, :email, :name, :status, :custom_attributes, :last_sign_in_at, :created_at, :updated_at

  attribute :email_verified, &:email_verified?
  attribute :mfa_enabled, &:mfa_enabled?
  attribute(:invitation_pending) { |end_user| !end_user.password_set? }
end
