require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user sign-in", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/sign-in" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    post "Sign in an end user" do
      tags "End-user auth"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: EndUserAuth::SignInRequest.as_schema } }

      response 200, "tokens (access, ID and refresh), or a challenge to answer" do
        schema Schemas::SignInResult
      end

      response 401, "wrong email or password, or invalid app client" do
        schema Schemas::Error
      end

      response 403, "email not confirmed" do
        schema Schemas::Error
      end

      response 429, "locked out after too many failures" do
        schema Schemas::Error
      end
    end
  end

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let!(:end_user) { create(:end_user, project: project, email: "casey@shop.test", name: "Casey") }
  let(:body) { { client_id: app_client.uid, email: "casey@shop.test", password: "correct horse battery staple" } }

  def sign_in(status, request_body = body, &block)
    assert_api_response(:post, status, body: request_body, path_params: project_path_params(project), &block)
  end

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  it "returns access, ID and refresh tokens" do
    sign_in(200) { expect(parsed_body.keys).to include("access_token", "id_token", "refresh_token") }
  end

  it "issues tokens for the app client, from the project's issuer" do
    sign_in(200) do
      expect(claims(parsed_body["access_token"])).to include("aud" => app_client.uid, "iss" => project.token_issuer, "token_use" => "access")
    end
  end

  it "puts profile claims in the ID token" do
    sign_in(200) do
      expect(claims(parsed_body["id_token"])).to include("sub" => end_user.uid, "email" => "casey@shop.test", "email_verified" => true, "name" => "Casey")
    end
  end

  it "includes custom attributes marked for the token" do
    create(:end_user_attribute_definition, project: project, key: "plan", include_in_token: true)
    create(:end_user_attribute_definition, project: project, key: "notes")
    end_user.update!(custom_attributes: { "plan" => "pro", "notes" => "private" })

    sign_in(200) { expect(claims(parsed_body["id_token"])["custom_attributes"]).to eq("plan" => "pro") }
  end

  it "signs with the project's own key, not the account's" do
    sign_in(200) do
      kid = JWT.decode(parsed_body["access_token"], nil, false).last["kid"]
      expect(project.signing_keys.pluck(:kid)).to include(kid)
    end
  end

  it "rejects a wrong password" do
    sign_in(401, body.merge(password: "wrong wrong wrong")) { expect(error_code).to eq("invalid_credentials") }
  end

  it "rejects an invited end user who hasn't set a password yet" do
    create(:end_user, :invited, project: project, email: "invited@shop.test")

    sign_in(401, body.merge(email: "invited@shop.test")) { expect(error_code).to eq("invalid_credentials") }
  end

  it "does not let console users sign in here" do
    create(:user, account: project.account, email: "admin@shop.test")

    sign_in(401, body.merge(email: "admin@shop.test"))
  end

  it "requires a confirmed email by default" do
    end_user.update!(email_verified_at: nil)

    sign_in(403) { expect(error_code).to eq("email_not_verified") }
  end

  it "locks the email after the project's lockout threshold" do
    project.auth_configuration!.update!(lockout_threshold: 3)
    3.times { sign_in(401, body.merge(password: "wrong wrong wrong")) }

    sign_in(429) { expect(error_code).to eq("too_many_attempts") }
  end

  it "records the sign-in in the project's audit log with the app client" do
    sign_in(200)

    expect(AuditEvent.where(project: project).last).to have_attributes(action: "end_user.signed_in", app_client_uid: app_client.uid)
  end

  it "asks for a TOTP code when the end user has MFA" do
    end_user.destroy!
    create(:end_user, :with_mfa, project: project, email: "casey@shop.test")

    sign_in(200) { expect(parsed_body["challenge"]).to eq("otp") }
  end
end
