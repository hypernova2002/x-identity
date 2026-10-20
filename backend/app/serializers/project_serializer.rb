class ProjectSerializer
  include Alba::Resource

  attributes :uid, :name, :created_at, :updated_at
end
