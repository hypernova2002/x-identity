require "rails_helper"

RSpec.describe Passkeys::SignInRequest do
  let(:valid_body) { { authentication_id: "authentication-id", credential: { "id" => "credential-id" } } }

  it_behaves_like "a passkey sign-in request"
end
