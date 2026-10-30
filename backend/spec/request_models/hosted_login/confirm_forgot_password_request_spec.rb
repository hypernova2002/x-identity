require "rails_helper"

RSpec.describe HostedLogin::ConfirmForgotPasswordRequest do
  let(:valid_body) { { email: "dana@acme.test", code: "123456", password: "a-good-password" } }

  it_behaves_like "a required field", :email
  it_behaves_like "an email lookup field", :email

  it_behaves_like "a required field", :code
  it_behaves_like "an email code field", :code

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password
end
