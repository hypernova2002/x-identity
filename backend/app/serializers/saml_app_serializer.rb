class SamlAppSerializer
  include Alba::Resource

  attributes :uid, :name, :enabled, :entity_id, :acs_urls, :slo_url, :sp_certificate, :name_id_format, :attribute_mappings,
    :sign_assertion, :sign_response, :require_signed_requests, :default_relay_state, :launch_url, :created_at, :updated_at
end
