require "rails_helper"

RSpec.describe Auth::ResetPasswordRequest do
  let(:valid_body) { { token: "reset-token", password: "a-good-password" } }

  it_behaves_like "a required field", :token
  it_behaves_like "a token field", :token

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password
end
