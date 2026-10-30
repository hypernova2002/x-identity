require "rails_helper"

RSpec.describe EndUserAuth::ProviderIdTokenRequest do
  let(:valid_body) { { client_id: "app_123", id_token: "header.payload.signature", nonce: "n" * 16 } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a required field", :id_token
  it_behaves_like "a jwt field", :id_token

  it_behaves_like "a required field", :nonce
  it_behaves_like "a string field", :nonce, min: 16, max: 256

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name
end
