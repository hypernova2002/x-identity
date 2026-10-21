require "rails_helper"
require "openapi_helper"

RSpec.describe "Token refresh", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/auth/refresh" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    post "Exchange a refresh token for new tokens" do
      tags "Sign in"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: Auth::RefreshRequest.as_schema } }

      response 200, "new tokens" do
        schema Schemas::TokenSet
      end

      response 401, "invalid, reused or expired refresh token" do
        schema Schemas::Error
      end
    end
  end

  let(:account) { create(:account) }
  let(:configuration) { account.auth_configuration! }
  let(:user) { create(:user, account: account) }
  let(:tokens) { tokens_for(user) }
  let(:path_params) { { account_uid: account.uid } }

  def refresh(status, token = tokens.refresh_token, &block)
    assert_api_response(:post, status, body: { refresh_token: token }, path_params: path_params, &block)
  end

  it "returns a new refresh token" do
    refresh(200) { expect(parsed_body["refresh_token"]).not_to eq(tokens.refresh_token) }
  end

  it "rejects a refresh token that was already used" do
    refresh(200)

    refresh(401) { expect(error_code).to eq("invalid_token") }
  end

  it "revokes the whole family when a used token is replayed" do
    replacement = nil
    refresh(200) { replacement = parsed_body["refresh_token"] }
    refresh(401)

    refresh(401, replacement)
  end

  it "rejects tokens issued by another account" do
    other_tokens = tokens_for(create(:user))

    refresh(401, other_tokens.refresh_token)
  end

  it "expires sessions left idle longer than the configured timeout" do
    configuration.update!(session_idle_timeout_seconds: 30.minutes.to_i)
    tokens

    travel 31.minutes do
      refresh(401) { expect(error_code).to eq("session_expired") }
    end
  end

  it "keeps the family's original expiry across rotations" do
    original_expiry = RefreshToken.find_by_token(tokens.refresh_token).expires_at

    refresh(200) { expect(RefreshToken.find_by_token(parsed_body["refresh_token"]).expires_at).to eq(original_expiry) }
  end

  it "refuses sessions without OTP once the account requires MFA" do
    configuration.update!(mfa_requirement: "required")

    refresh(401) { expect(error_code).to eq("mfa_required") }
  end

  it "refuses disabled users" do
    user.update!(status: "disabled")

    refresh(401)
  end
end
