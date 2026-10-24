class ApiResourceSerializer
  include Alba::Resource

  attributes :uid, :name, :identifier, :access_token_ttl_seconds, :created_at, :updated_at
  attribute(:scopes) { |api| api.scopes.map { |scope| { name: scope["name"], description: scope["description"] } } }
  attribute(:app_count) { |api| api.api_grants.size }
end
