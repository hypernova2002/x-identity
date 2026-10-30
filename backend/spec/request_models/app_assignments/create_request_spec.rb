require "rails_helper"

RSpec.describe AppAssignments::CreateRequest do
  let(:valid_body) { { principal_type: "group", principal_uid: "grp_123" } }

  it_behaves_like "a required field", :principal_type
  it_behaves_like "an enum field", :principal_type, values: %w[end_user group]

  it_behaves_like "a required field", :principal_uid
  it_behaves_like "a uid field", :principal_uid
end
