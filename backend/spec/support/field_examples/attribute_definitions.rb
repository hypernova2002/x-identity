# The fields of AttributeDefinitions::Fields, shared by the create and update requests. `required`
# lists the fields the request requires; the rest are optional.
RSpec.shared_examples "attribute definition fields" do |required: []|
  it_behaves_like(required.include?(:label) ? "a required field" : "an optional field", :label)
  it_behaves_like "a name field", :label
  it_behaves_like "an optional field", :max_length
  it_behaves_like "an integer field", :max_length, min: 1, max: EndUserAttributeDefinition::MAX_STRING_LENGTH, nullable: true

  %i[required user_editable include_in_token].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "a boolean field", field
  end
end
