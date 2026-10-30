require "rails_helper"

RSpec.describe ProjectMembers::CreateRequest do
  let(:valid_body) { { user_uid: "usr_123", role: "developer" } }

  it_behaves_like "a required field", :user_uid
  it_behaves_like "a uid field", :user_uid

  it_behaves_like "a required field", :role
  it_behaves_like "a project role field", :role
end
