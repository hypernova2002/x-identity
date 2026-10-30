require "rails_helper"

RSpec.describe EndUserAuth::ProviderTokenRequest do
  let(:valid_body) { { client_id: "app_123", code: "provider-code", code_verifier: "v" * 43, redirect_uri: "https://shop.test/callback" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a required field", :code
  it_behaves_like "a token field", :code

  it_behaves_like "a required field", :code_verifier
  it_behaves_like "a string field", :code_verifier, min: 43, max: 128

  it_behaves_like "a required field", :redirect_uri
  it_behaves_like "a url field", :redirect_uri
end
