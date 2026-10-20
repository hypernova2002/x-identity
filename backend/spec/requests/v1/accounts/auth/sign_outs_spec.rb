require "rails_helper"
require "openapi_helper"

RSpec.describe "Sign out", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/auth/sign-out" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    post "Revoke the session behind a refresh token" do
      tags "Sign in"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: RefreshTokenRequest.as_schema } }

      response 204, "signed out"
    end
  end

  let(:user) { create(:user) }
  let(:tokens) { tokens_for(user) }

  it "revokes the refresh token" do
    assert_api_response :post, 204, body: { refresh_token: tokens.refresh_token }, path_params: { account_uid: user.account.uid }

    expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
  end

  it "succeeds for unknown tokens" do
    assert_api_response :post, 204, body: { refresh_token: "unknown" }, path_params: { account_uid: user.account.uid }
  end
end
