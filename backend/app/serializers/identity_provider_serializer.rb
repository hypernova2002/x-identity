# Secrets are never returned, only whether one is set.
class IdentityProviderSerializer
  include Alba::Resource

  attributes :uid, :kind, :name, :enabled, :client_id, :additional_audiences, :scopes, :discovery_url,
    :apple_team_id, :apple_key_id, :callback_url, :saml_idp_entity_id, :saml_sso_url, :saml_slo_url, :saml_idp_certificates,
    :saml_name_id_format, :saml_email_attribute, :saml_name_attribute, :saml_groups_attribute, :domains, :create_users,
    :allow_idp_initiated, :created_at, :updated_at
  attribute(:on_custom_domain) { |provider| provider.on_custom_domain if provider.kind_saml? }
  attribute(:sp_entity_id) { |provider| provider.sp_entity_id if provider.kind_saml? }
  attribute(:acs_url) { |provider| provider.acs_url if provider.kind_saml? }
  attribute(:sp_slo_url) { |provider| provider.sp_slo_url if provider.kind_saml? }
  attribute(:group_mappings) do |provider|
    provider.group_mappings.sort_by(&:value).map { |mapping| { value: mapping.value, group_uid: mapping.group.uid, group_name: mapping.group.name } }
  end
  attribute(:issuer) { |provider| provider.endpoints["issuer"] }
  attribute(:client_secret_set) { |provider| provider.client_secret.present? }
  attribute(:apple_private_key_set) { |provider| provider.apple_private_key.present? }
end
