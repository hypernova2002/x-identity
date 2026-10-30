require "rails_helper"

RSpec.describe EndUserAuth::AcceptInvitationRequest do
  let(:valid_body) { { client_id: "app_123", password: "a-good-password" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password

  it_behaves_like "an email code or link request"
end
