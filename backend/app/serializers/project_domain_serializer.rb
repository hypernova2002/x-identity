class ProjectDomainSerializer
  include Alba::Resource

  attributes :uid, :hostname, :status, :verified_at, :last_checked_at, :check_error, :dns_missing_since, :certificate_status, :verify_until, :created_at
  # The project's SAML connections, and whether each uses the custom domain, to say what removing or
  # replacing it affects and what still uses the standard URLs.
  attribute(:saml_apps) { |domain| domain.project.saml_apps.order(:name, :id).map { |app| { uid: app.uid, name: app.name, on_custom_domain: app.on_custom_domain } } }
  attribute(:saml_identity_providers) do |domain|
    domain.project.identity_providers.kind_saml.order(:name, :id).map { |provider| { uid: provider.uid, name: provider.name, on_custom_domain: provider.on_custom_domain } }
  end
  attribute(:dns_records) do |domain|
    [
      { type: "CNAME", name: domain.hostname, value: domain.cname_target },
      { type: "TXT", name: domain.txt_record_name, value: domain.verification_token }
    ]
  end
end
