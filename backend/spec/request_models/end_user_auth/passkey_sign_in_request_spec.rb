require "rails_helper"

RSpec.describe EndUserAuth::PasskeySignInRequest do
  let(:valid_body) { { client_id: "app_123", authentication_id: "authentication-id", credential: { "id" => "credential-id" } } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a passkey sign-in request"
end
