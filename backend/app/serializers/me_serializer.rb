class MeSerializer < UserSerializer
  attributes :password_changed_at

  one :account, resource: AccountSerializer
end
