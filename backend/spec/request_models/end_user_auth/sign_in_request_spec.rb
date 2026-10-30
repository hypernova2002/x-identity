require "rails_helper"

RSpec.describe EndUserAuth::SignInRequest do
  let(:valid_body) { { client_id: "app_123", email: "dana@acme.test", password: "a-good-password" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "an email and password request"
end
