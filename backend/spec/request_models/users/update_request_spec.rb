require "rails_helper"

RSpec.describe Users::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :role
  it_behaves_like "an account role field", :role

  it_behaves_like "an optional field", :status
  it_behaves_like "an enum field", :status, values: User.statuses.keys
end
