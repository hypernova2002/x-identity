require "rails_helper"

RSpec.describe EndUserAuth::ProviderAuthorizeRequest do
  let(:valid_body) { { client_id: "app_123", redirect_uri: "https://shop.test/callback", state: "state", code_challenge: "a" * 43, code_challenge_method: "S256" } }

  it_behaves_like "a required field", :client_id
  it_behaves_like "a uid field", :client_id

  it_behaves_like "a required field", :redirect_uri
  it_behaves_like "a url field", :redirect_uri

  it_behaves_like "a required field", :state
  it_behaves_like "a string field", :state, min: 1, max: 512

  it_behaves_like "a required field", :code_challenge
  it_behaves_like "a string field", :code_challenge, min: 43, max: 43

  it_behaves_like "a required field", :code_challenge_method
  it_behaves_like "an enum field", :code_challenge_method, values: %w[S256]
end
