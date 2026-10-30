require "rails_helper"

RSpec.describe Groups::AddMemberRequest do
  let(:valid_body) { { end_user_uid: "eu_123" } }

  it_behaves_like "a required field", :end_user_uid
  it_behaves_like "a uid field", :end_user_uid
end
