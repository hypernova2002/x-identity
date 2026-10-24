class AppClientSerializer
  include Alba::Resource

  attributes :uid, :name, :client_type, :machine, :allowed_origins, :redirect_uris, :post_logout_redirect_uris, :launch_url, :enabled,
    :token_requests_per_minute, :created_at, :updated_at
end
