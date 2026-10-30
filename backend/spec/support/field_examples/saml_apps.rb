# The fields of SamlApps::Fields, shared by the create and update requests. `required` lists the
# fields the request requires; the rest are optional.
RSpec.shared_examples "saml app fields" do |required: []|
  presence = ->(field) { required.include?(field) ? "a required field" : "an optional field" }

  it_behaves_like presence.call(:name), :name
  it_behaves_like "a name field", :name
  it_behaves_like presence.call(:entity_id), :entity_id
  it_behaves_like "a saml entity id field", :entity_id
  it_behaves_like presence.call(:acs_urls), :acs_urls
  it_behaves_like "an array field", :acs_urls,
    min: 1, max: SamlApp::MAX_ACS_URLS, item: "https://shop.test/acs", item_max: WebUrl::MAX_LENGTH, invalid_items: [ "" ]

  it_behaves_like "an optional field", :slo_url
  it_behaves_like "a url field", :slo_url, nullable: true
  it_behaves_like "an optional field", :sp_certificate
  it_behaves_like "a certificate field", :sp_certificate, nullable: true
  it_behaves_like "an optional field", :name_id_format
  it_behaves_like "a saml name id format field", :name_id_format
  it_behaves_like "an optional field", :attribute_mappings
  it_behaves_like "an array field", :attribute_mappings,
    max: SamlApp::MAX_ATTRIBUTES, item: { name: "email", source: "email" }, invalid_items: [ {}, { name: "email" }, "email" ]
  it_behaves_like "an optional field", :default_relay_state
  it_behaves_like "a string field", :default_relay_state, min: 1, max: 1024, nullable: true

  %i[sign_assertion sign_response require_signed_requests enabled].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "a boolean field", field
  end
end
