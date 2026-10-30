require "rails_helper"

RSpec.describe Auth::AcceptInvitationRequest do
  let(:valid_body) { { token: "invite-token", name: "Dana", password: "a-good-password" } }

  it_behaves_like "a required field", :token
  it_behaves_like "a token field", :token

  it_behaves_like "a required field", :name
  it_behaves_like "a name field", :name

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password
end
