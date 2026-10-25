class MeSerializer < UserSerializer
  attributes :password_changed_at

  attribute(:otp_method) { |user| user.account.auth_configuration!.otp_method }
  attribute(:passkeys_available) { |user| user.account.auth_configuration!.passkeys_optional? }

  one :account, resource: AccountSerializer
end
