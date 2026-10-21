require "rails_helper"
require "openapi_helper"

RSpec.describe "Sign in", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/auth/sign-in" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    post "Sign in with email and password" do
      tags "Sign in"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: Auth::SignInRequest.as_schema } }

      response 200, "tokens, or a challenge to answer" do
        schema Schemas::SignInResult
      end

      response 401, "wrong email or password" do
        schema Schemas::Error
      end

      response 403, "email not verified" do
        schema Schemas::Error
      end

      response 404, "unknown account" do
        schema Schemas::Error
      end

      response 429, "locked out after too many failures" do
        schema Schemas::Error
      end
    end
  end

  let(:account) { create(:account) }
  let(:configuration) { account.auth_configuration! }
  let!(:user) { create(:user, account: account, email: "dana@acme.test") }
  let(:path_params) { { account_uid: account.uid } }
  let(:credentials) { { email: "Dana@Acme.test", password: "correct horse battery staple" } }

  def sign_in(status, body = credentials, &block)
    assert_api_response(:post, status, body: body, path_params: path_params, &block)
  end

  it "returns tokens for valid credentials" do
    sign_in 200 do
      expect(parsed_body.keys).to include("access_token", "refresh_token")
    end
  end

  it "issues an access token whose subject is the user's uid" do
    sign_in 200 do
      claims = Auth::AccessTokenVerifier.new(realm: account.realm).verify(parsed_body["access_token"])
      expect(claims["sub"]).to eq(user.uid)
    end
  end

  it "rejects a wrong password" do
    sign_in(401, credentials.merge(password: "wrong password!!")) { expect(error_code).to eq("invalid_credentials") }
  end

  it "responds the same way for an unknown email" do
    sign_in(401, credentials.merge(email: "nobody@acme.test")) { expect(error_code).to eq("invalid_credentials") }
  end

  it "rejects disabled users with the generic error" do
    user.update!(status: "disabled")

    sign_in(401) { expect(error_code).to eq("invalid_credentials") }
  end

  it "does not accept credentials from another account" do
    other_account = create(:account)

    assert_api_response :post, 401, body: credentials, path_params: { account_uid: other_account.uid }
  end

  it "returns not_found for an unknown account" do
    assert_api_response :post, 404, body: credentials, path_params: { account_uid: "acct_missing" }
  end

  it "locks the email after the configured number of failures" do
    configuration.update!(lockout_threshold: 3)
    3.times { sign_in(401, credentials.merge(password: "wrong password!!")) }

    sign_in(429) { expect(error_code).to eq("too_many_attempts") }
  end

  it "keeps lockouts separate per account" do
    configuration.update!(lockout_threshold: 3)
    3.times { sign_in(401, credentials.merge(password: "wrong password!!")) }
    other_user = create(:user, email: "dana@acme.test")

    assert_api_response :post, 200, body: credentials, path_params: { account_uid: other_user.account.uid }
  end

  it "records failed attempts in the audit log" do
    sign_in(401, credentials.merge(password: "wrong password!!"))

    expect(account.audit_events.pluck(:action)).to eq([ "user.sign_in_failed" ])
  end

  context "when email verification is required" do
    before { configuration.update!(require_email_verification: true) }

    it "refuses unverified users" do
      user.update!(email_verified_at: nil)

      sign_in(403) { expect(error_code).to eq("email_not_verified") }
    end

    it "signs in verified users" do
      sign_in 200
    end
  end

  context "when the user has MFA turned on" do
    let!(:user) { create(:user, :with_mfa, account: account, email: "dana@acme.test") }

    it "asks for a TOTP code" do
      sign_in(200) { expect(parsed_body["challenge"]).to eq("otp") }
    end

    it "skips the code when the account turned MFA off" do
      configuration.update!(mfa_requirement: "off")

      sign_in(200) { expect(parsed_body).to include("access_token") }
    end
  end

  it "asks users without MFA to set it up when the account requires it" do
    configuration.update!(mfa_requirement: "required")

    sign_in(200) { expect(parsed_body["challenge"]).to eq("mfa_setup") }
  end

  it "asks for a new password once the password is older than the maximum age" do
    configuration.update!(password_max_age_seconds: 30.days.to_i)
    user.update!(password_changed_at: 31.days.ago)

    sign_in(200) { expect(parsed_body["challenge"]).to eq("new_password") }
  end
end
