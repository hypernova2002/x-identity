require "rails_helper"

RSpec.describe ProjectMembers::UpdateRequest do
  let(:valid_body) { { role: "developer" } }

  it_behaves_like "a required field", :role
  it_behaves_like "a project role field", :role
end
