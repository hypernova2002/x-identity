require "rails_helper"

RSpec.describe HostedLogin::ConfirmSignUpRequest do
  let(:valid_body) { { email: "dana@acme.test", code: "123456" } }

  it_behaves_like "a required field", :email
  it_behaves_like "an email lookup field", :email

  it_behaves_like "a required field", :code
  it_behaves_like "an email code field", :code
end
