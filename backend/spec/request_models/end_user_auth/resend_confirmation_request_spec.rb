require "rails_helper"

RSpec.describe EndUserAuth::ResendConfirmationRequest do
  let(:valid_body) { { client_id: "app_123", email: "dana@acme.test" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "an email lookup request"
end
