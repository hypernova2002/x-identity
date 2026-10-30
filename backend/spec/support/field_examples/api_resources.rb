# The fields of ApiResources::Fields, shared by the create and update requests. `required` lists
# the fields the request requires; the rest are optional.
RSpec.shared_examples "api resource fields" do |required: []|
  it_behaves_like(required.include?(:name) ? "a required field" : "an optional field", :name)
  it_behaves_like "a name field", :name
  it_behaves_like "an optional field", :scopes
  it_behaves_like "an array field", :scopes,
    max: ApiResource::MAX_SCOPES, item: { name: "orders:read" }, invalid_items: [ {}, { name: "" }, "orders:read" ]
  it_behaves_like "an optional field", :access_token_ttl_seconds
  it_behaves_like "an integer field", :access_token_ttl_seconds,
    min: ApiResource::ACCESS_TOKEN_TTL_SECONDS.min, max: ApiResource::ACCESS_TOKEN_TTL_SECONDS.max, nullable: true
end

RSpec.shared_examples "api grant scopes" do
  it_behaves_like "a required field", :scopes
  it_behaves_like "an array field", :scopes, max: ApiResource::MAX_SCOPES, item: "orders:read", item_max: 64, invalid_items: [ "" ]
end
