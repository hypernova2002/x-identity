require "rails_helper"
require "openapi_helper"
require "webauthn/fake_client"

RSpec.describe "End-user sign-in challenges", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project, allowed_origins: [ "https://app.acme.com" ]) }
  let(:path_params) { project_path_params(project) }

  def start_sign_in(end_user)
    post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/sign-in",
      params: { client_id: app_client.uid, email: end_user.email, password: "correct horse battery staple" }, as: :json
    response.parsed_body
  end

  describe "responding to a challenge" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/respond-to-challenge" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Answer a sign-in challenge" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ChallengeResponseRequest.as_schema } }

        response 200, "tokens, or the next challenge" do
          schema Schemas::SignInResult
        end

        response 401, "wrong code, invalid session or invalid app client" do
          schema Schemas::Error
        end

        response 403, "end user disabled after too many wrong codes in a row" do
          schema Schemas::Error
        end

        response 422, "invalid new password" do
          schema Schemas::Error
        end

        response 429, "locked out after too many failures" do
          schema Schemas::Error
        end
      end
    end

    let(:end_user) { create(:end_user, :with_mfa, project: project) }
    let(:session) { start_sign_in(end_user).fetch("session") }

    it "returns tokens for the app client once the code is right" do
      body = { client_id: app_client.uid, challenge: "otp", session: session }

      assert_api_response :post, 401, body: body.merge(code: "000000"), path_params: path_params
      assert_api_response(:post, 200, body: body.merge(code: current_totp_for(end_user)), path_params: path_params) do
        expect(JWT.decode(parsed_body["access_token"], nil, false).first).to include("aud" => app_client.uid, "amr" => %w[pwd otp])
      end
    end

    it "needs the app client the sign-in started with" do
      other = create(:app_client, project: project)

      assert_api_response :post, 401, body: { client_id: other.uid, challenge: "otp", session: session, code: current_totp_for(end_user) }, path_params: path_params
    end
  end

  describe "setting up MFA" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/mfa-setup" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Get a TOTP secret while answering an mfa_setup challenge" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::MfaSetupRequest.as_schema } }

        response 200, "secret and QR code; answer with respond-to-challenge, challenge: mfa_setup" do
          schema Schemas::MfaEnrollment
        end

        response 401, "invalid session or app client" do
          schema Schemas::Error
        end
      end
    end

    it "returns a secret for an end user answering mfa_setup, and signs them in with its code" do
      project.auth_configuration!.update!(mfa_requirement: "required")
      challenge = start_sign_in(create(:end_user, project: project))
      expect(challenge["challenge"]).to eq("mfa_setup")

      secret = nil
      assert_api_response(:post, 200, body: { client_id: app_client.uid, session: challenge["session"] }, path_params: path_params) do
        secret = parsed_body["secret"]
      end
      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/respond-to-challenge",
        params: { client_id: app_client.uid, challenge: "mfa_setup", session: challenge["session"], code: ROTP::TOTP.new(secret).now }, as: :json

      expect(response.parsed_body).to have_key("access_token")
    end

    it "refuses sessions issued for other challenges" do
      session = start_sign_in(create(:end_user, :with_mfa, project: project)).fetch("session")

      assert_api_response :post, 401, body: { client_id: app_client.uid, session: session }, path_params: path_params
    end
  end

  describe "setting up a passkey" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey-setup" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Options for creating the passkey a passkey_setup challenge asks for" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::PasskeySetupRequest.as_schema } }

        response 200, "options for navigator.credentials.create; answer with respond-to-challenge, challenge: passkey_setup" do
          schema Schemas::PasskeyRegistrationOptions
        end

        response 401, "invalid session or app client" do
          schema Schemas::Error
        end
      end
    end

    before do
      project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
      project.auth_configuration!.update!(passkeys: "required")
    end

    it "creates the passkey from the app's allowed origin, and signs the end user in" do
      end_user = create(:end_user, project: project)
      challenge = start_sign_in(end_user)
      expect(challenge["challenge"]).to eq("passkey_setup")

      options = nil
      assert_api_response(:post, 200, body: { client_id: app_client.uid, session: challenge["session"] }, path_params: path_params) do
        options = parsed_body
        expect(options.dig("public_key", "rp", "id")).to eq("login.acme.com")
      end
      credential = WebAuthn::FakeClient.new("https://app.acme.com", encoding: :base64url)
        .create(challenge: options.dig("public_key", "challenge"), rp_id: "login.acme.com", user_verified: true)
      body = { client_id: app_client.uid, challenge: "passkey_setup", session: challenge["session"], registration_id: options["registration_id"], credential: credential }

      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/respond-to-challenge", params: body, as: :json

      expect(response.parsed_body).to have_key("access_token")
      expect(end_user.webauthn_credentials.count).to eq(1)
    end

    it "refuses sessions issued for other challenges" do
      project.auth_configuration!.update!(passkeys: "optional")
      session = start_sign_in(create(:end_user, :with_mfa, project: project)).fetch("session")

      assert_api_response :post, 401, body: { client_id: app_client.uid, session: session }, path_params: path_params
    end
  end
end
