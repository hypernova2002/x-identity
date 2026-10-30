# The fields of Groups::Fields, shared by the create and update requests. `required` lists the
# fields the request requires; the rest are optional.
RSpec.shared_examples "group fields" do |required: []|
  it_behaves_like(required.include?(:name) ? "a required field" : "an optional field", :name)
  it_behaves_like "a name field", :name
  it_behaves_like "an optional field", :description
  it_behaves_like "a string field", :description, min: 1, max: 500, nullable: true
  it_behaves_like "an optional field", :default_for_new_users
  it_behaves_like "a boolean field", :default_for_new_users
end
