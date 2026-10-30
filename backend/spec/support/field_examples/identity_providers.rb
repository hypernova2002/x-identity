# The fields of IdentityProviders::Fields, shared by the create and update requests. `required`
# lists the fields the request requires; the rest are optional.
RSpec.shared_examples "identity provider fields" do |required: []|
  it_behaves_like(required.include?(:name) ? "a required field" : "an optional field", :name)
  it_behaves_like "a name field", :name

  {
    client_id: 1..255,
    scopes: 1..500,
    apple_team_id: 10..10,
    apple_key_id: 10..10
  }.each do |field, length|
    it_behaves_like "an optional field", field
    it_behaves_like "a string field", field, min: length.min, max: length.max
  end

  %i[saml_email_attribute saml_name_attribute saml_groups_attribute].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "a string field", field, min: 1, max: 255, nullable: true
  end

  it_behaves_like "an optional field", :discovery_url
  it_behaves_like "a url field", :discovery_url
  it_behaves_like "an optional field", :saml_idp_entity_id
  it_behaves_like "a saml entity id field", :saml_idp_entity_id
  it_behaves_like "an optional field", :saml_sso_url
  it_behaves_like "a url field", :saml_sso_url
  it_behaves_like "an optional field", :saml_slo_url
  it_behaves_like "a url field", :saml_slo_url, nullable: true
  it_behaves_like "an optional field", :saml_name_id_format
  it_behaves_like "a saml name id format field", :saml_name_id_format

  it_behaves_like "an optional field", :additional_audiences
  it_behaves_like "an array field", :additional_audiences,
    max: IdentityProvider::MAX_AUDIENCES, item: "com.shop.ios", item_max: 255, invalid_items: [ "" ]
  it_behaves_like "an optional field", :saml_idp_certificates
  it_behaves_like "an array field", :saml_idp_certificates,
    max: IdentityProvider::MAX_CERTIFICATES, item: "certificate", item_max: 10_000, invalid_items: [ "" ]
  it_behaves_like "an optional field", :domains
  it_behaves_like "an array field", :domains, max: IdentityProvider::MAX_DOMAINS, item: "acme.test", item_max: 253, invalid_items: [ "" ]
  it_behaves_like "an optional field", :group_mappings
  it_behaves_like "an array field", :group_mappings,
    max: 100, item: { value: "staff", group_uid: "grp_123" }, invalid_items: [ {}, { value: "staff" }, "staff" ]

  %i[create_users allow_idp_initiated enabled].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "a boolean field", field
  end
end
