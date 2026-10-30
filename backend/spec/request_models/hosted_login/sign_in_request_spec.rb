require "rails_helper"

RSpec.describe HostedLogin::SignInRequest do
  let(:valid_body) { { email: "dana@acme.test", password: "a-good-password" } }

  it_behaves_like "an email and password request"
end
