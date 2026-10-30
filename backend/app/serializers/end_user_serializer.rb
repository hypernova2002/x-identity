class EndUserSerializer
  include Alba::Resource

  attributes :uid, :email, :name, :status, :custom_attributes, :locale, :last_sign_in_at, :created_at, :updated_at

  attribute :email_verified, &:email_verified?
  attribute :mfa_enabled, &:mfa_enabled?
  attribute(:invitation_pending) { |end_user| !end_user.password_set? && end_user.identities.none? }
  attribute(:groups) { |end_user| end_user.groups.sort_by(&:name).map { |group| { uid: group.uid, name: group.name } } }
end
