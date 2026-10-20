class AccountSerializer
  include Alba::Resource

  attributes :uid, :name, :slug, :created_at, :updated_at
end
