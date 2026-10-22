class AppClientSerializer
  include Alba::Resource

  attributes :uid, :name, :client_type, :allowed_origins, :redirect_uris, :post_logout_redirect_uris, :launch_url, :enabled, :created_at, :updated_at
end
