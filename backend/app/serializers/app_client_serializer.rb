class AppClientSerializer
  include Alba::Resource

  attributes :uid, :name, :client_type, :allowed_origins, :enabled, :created_at, :updated_at
end
