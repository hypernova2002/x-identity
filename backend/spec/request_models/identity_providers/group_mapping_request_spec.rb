require "rails_helper"

RSpec.describe IdentityProviders::GroupMappingRequest do
  let(:valid_body) { { value: "staff", group_uid: "grp_123" } }

  it_behaves_like "a required field", :value
  it_behaves_like "a string field", :value, min: 1, max: 255

  it_behaves_like "a required field", :group_uid
  it_behaves_like "a uid field", :group_uid
end
