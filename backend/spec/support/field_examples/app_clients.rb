# The fields of AppClients::Fields, shared by the create and update requests. `required` lists the
# fields the request requires; the rest are optional.
RSpec.shared_examples "app client fields" do |required: []|
  it_behaves_like(required.include?(:name) ? "a required field" : "an optional field", :name)
  it_behaves_like "a name field", :name
  it_behaves_like "an optional field", :allowed_origins
  it_behaves_like "an array field", :allowed_origins, max: AppClient::MAX_ORIGINS, item: "https://shop.test", item_max: 255, invalid_items: [ "" ]

  %i[redirect_uris post_logout_redirect_uris].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "an array field", field,
      max: AppClient::MAX_REDIRECT_URIS, item: "https://shop.test/callback", item_max: WebUrl::MAX_LENGTH, invalid_items: [ "" ]
  end

  it_behaves_like "an optional field", :launch_url
  it_behaves_like "a url field", :launch_url, nullable: true
end
