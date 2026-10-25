class ProjectDomainSerializer
  include Alba::Resource

  attributes :uid, :hostname, :status, :verified_at, :last_checked_at, :check_error, :dns_missing_since, :certificate_status, :verify_until, :created_at
  # The project's SAML connections, and whether each uses the custom domain, to say what removing or
  # replacing it affects and what still uses the standard URLs.
  attribute(:saml_apps) { |domain| domain.project.saml_apps.order(:name, :id).map { |app| { uid: app.uid, name: app.name, on_custom_domain: app.on_custom_domain } } }
  attribute(:saml_identity_providers) do |domain|
    domain.project.identity_providers.kind_saml.order(:name, :id).map { |provider| { uid: provider.uid, name: provider.name, on_custom_domain: provider.on_custom_domain } }
  end
  # End users' passkeys that belong to the domain, which stop working if it's removed or replaced.
  attribute(:passkey_count) do |domain|
    WebauthnCredential.where(rp_id: domain.hostname, subject_type: "EndUser", subject_id: domain.project.end_users.select(:id)).count
  end
  # Other origins listed in the domain's /.well-known/webauthn, which can use its passkeys.
  attribute(:passkey_related_origins) { |domain| domain.status_verified? ? Passkeys::RelyingParties.related_origins(domain.project) : [] }
  attribute(:dns_records) do |domain|
    [
      { type: "CNAME", name: domain.hostname, value: domain.cname_target },
      { type: "TXT", name: domain.txt_record_name, value: domain.verification_token }
    ]
  end
end
