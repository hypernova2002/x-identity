require "rails_helper"
require "openapi_helper"

RSpec.describe "JWKS", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/.well-known/jwks.json" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    get "Public keys for verifying the account's access tokens" do
      tags "Sign in"

      response 200, "JSON Web Key Set" do
        schema type: :object, required: %w[keys], properties: { keys: { type: :array, items: { type: :object } } }
      end
    end
  end

  let(:account) { create(:account) }

  it "publishes the key that signed the account's tokens" do
    token = tokens_for(create(:user, account: account)).access_token
    kid = JWT.decode(token, nil, false).last["kid"]

    assert_api_response :get, 200, path_params: { account_uid: account.uid } do
      expect(parsed_body["keys"].pluck("kid")).to eq([ kid ])
    end
  end

  it "does not publish private key material" do
    tokens_for(create(:user, account: account))

    assert_api_response :get, 200, path_params: { account_uid: account.uid } do
      expect(parsed_body["keys"].first.keys).not_to include("d")
    end
  end
end
