class ApiGrantSerializer
  include Alba::Resource

  attributes :uid, :scopes, :created_at, :updated_at
  attribute(:api_uid) { |grant| grant.api_resource.uid }
  attribute(:api_name) { |grant| grant.api_resource.name }
  attribute(:api_identifier) { |grant| grant.api_resource.identifier }
end
