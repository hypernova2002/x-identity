require "rails_helper"

RSpec.describe HostedLogin::SignUpRequest do
  let(:valid_body) { { email: "dana@acme.test", password: "a-good-password" } }

  it_behaves_like "a required field", :email
  it_behaves_like "an email field", :email

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name
end
