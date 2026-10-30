require "rails_helper"

RSpec.describe AttributeDefinitions::CreateRequest do
  let(:valid_body) { { key: "plan", label: "Plan", data_type: "string" } }

  it_behaves_like "a required field", :key
  it_behaves_like "a string field", :key, min: 1, max: EndUserAttributeDefinition::KEY_MAX_LENGTH
  it_behaves_like "a field accepting", :key, %w[plan plan_2 a]
  it_behaves_like "a field rejecting", :key, %w[Plan 2plan _plan plan-2]

  it_behaves_like "a required field", :data_type
  it_behaves_like "an enum field", :data_type, values: EndUserAttributeDefinition.data_types.keys

  it_behaves_like "attribute definition fields", required: %i[label]
end
