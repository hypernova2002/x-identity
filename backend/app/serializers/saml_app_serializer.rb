class SamlAppSerializer
  include Alba::Resource

  attributes :uid, :name, :enabled, :entity_id, :acs_urls, :slo_url, :sp_certificate, :name_id_format, :attribute_mappings,
    :sign_assertion, :sign_response, :require_signed_requests, :default_relay_state, :launch_url, :on_custom_domain, :created_at, :updated_at
  # What to enter in the app's SAML settings: the project's standard URLs, or its custom domain's.
  attribute(:idp) do |app|
    metadata = SamlIdp::Metadata.new(app.project, endpoints: app.project_endpoints)
    { entity_id: metadata.entity_id, metadata_url: metadata.entity_id, sso_url: metadata.sso_url, slo_url: metadata.slo_url }
  end
end
