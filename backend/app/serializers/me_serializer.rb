class MeSerializer < UserSerializer
  attributes :password_changed_at

  attribute(:otp_method) { |user| user.account.auth_configuration!.otp_method }

  one :account, resource: AccountSerializer
end
