class MeSerializer < UserSerializer
  attributes :password_changed_at

  attribute(:otp_methods) { |user| user.account.auth_configuration!.otp_methods }

  one :account, resource: AccountSerializer
end
