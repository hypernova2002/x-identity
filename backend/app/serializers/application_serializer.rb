class ApplicationSerializer
  include Alba::Resource

  attributes :app_type, :uid, :name, :enabled, :client_type, :machine, :entity_id, :created_at
end
