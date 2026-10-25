require "rails_helper"
require "openapi_helper"

RSpec.describe "Requiring passkeys", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account, email: "casey@acme.test") }
  let(:console) { URI.parse(Rails.configuration.x.console_base_url) }
  let(:console_origin) { "#{console.scheme}://#{console.host}:#{console.port}" }
  let(:path_params) { { account_uid: account.uid } }

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  def sign_in_with_password(email = "casey@acme.test")
    post "/v1/accounts/#{account.uid}/auth/sign-in", params: { email: email, password: "correct horse battery staple" }, as: :json
    response.parsed_body
  end

  describe "the setting" do
    it "needs MFA not to be off, and a project's custom domain" do
      configuration = account.auth_configuration!
      configuration.update!(mfa_requirement: "off")
      expect(configuration.update(passkeys: "required")).to be(false)
      expect(configuration.errors[:passkeys].first).to include("MFA is off")

      project = create(:project, account: account)
      expect(project.auth_configuration!.update(passkeys: "required")).to be(false)
      expect(project.auth_configuration!.errors[:passkeys].first).to include("verified custom domain")

      project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
      expect(project.auth_configuration!.update(passkeys: "required")).to be(true)
    end
  end

  describe "for console users" do
    before { account.auth_configuration!.update!(passkeys: "required") }

    api_path "/v1/accounts/{account_uid}/auth/passkey-setup" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Options for creating the passkey a passkey_setup challenge asks for" do
        tags "Authentication"
        request_body required: true, content: { "application/json" => { schema: Passkeys::SetupRequest.as_schema } }

        response 200, "options for navigator.credentials.create; answer with respond-to-challenge, challenge: passkey_setup" do
          schema Schemas::PasskeyRegistrationOptions
        end
      end
    end

    it "asks users without a passkey to create one before signing in" do
      challenge = sign_in_with_password
      expect(challenge["challenge"]).to eq("passkey_setup")

      options = nil
      assert_api_response(:post, 200, path_params: path_params, body: { session: challenge["session"] }) do
        options = parsed_body
        expect(parsed_body.dig("public_key", "rp", "id")).to eq(console.host)
      end
      credential = WebAuthn::FakeClient.new(console_origin, encoding: :base64url)
        .create(challenge: options.dig("public_key", "challenge"), rp_id: console.host, user_verified: true)
      post "/v1/accounts/#{account.uid}/auth/respond-to-challenge", params: {
        challenge: "passkey_setup", session: challenge["session"], registration_id: options["registration_id"], credential: credential
      }, as: :json

      expect(claims(response.parsed_body["access_token"])["amr"]).to eq(%w[pwd hwk user])
      expect(user.webauthn_credentials.count).to eq(1)
      expect(AuditEvent.where(action: "user.passkey_added").count).to eq(1)
    end

    it "asks users with a passkey to use it, even when they also have an authenticator app" do
      user = create(:user, :with_mfa, account: account, email: "both@acme.test")
      add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)

      expect(sign_in_with_password("both@acme.test")).to include("challenge" => "passkey", "mfa_methods" => [ "passkey" ])
    end

    it "lets a passkey sign-in straight through" do
      client = add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)
      post "/v1/accounts/#{account.uid}/auth/passkey/options"
      options = response.parsed_body

      post "/v1/accounts/#{account.uid}/auth/passkey", params: {
        authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: user, rp_id: console.host)
      }, as: :json

      expect(response.parsed_body).to have_key("access_token")
    end
  end

  describe "for end users" do
    let(:project) { create(:project, account: account) }
    let!(:domain) { project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current) }
    let(:native_app) { create(:app_client, project: project) }
    let(:base) { URI.parse(project.token_issuer).path }

    before { project.auth_configuration!.update!(passkeys: "required") }

    it "requires MFA instead where passkeys can't be used, such as an app without allowed origins" do
      create(:end_user, project: project, email: "plain@acme.com")
      create(:end_user, :with_mfa, project: project, email: "totp@acme.com")

      post "#{base}/auth/sign-in", params: { client_id: native_app.uid, email: "plain@acme.com", password: "correct horse battery staple" }, as: :json
      expect(response.parsed_body["challenge"]).to eq("mfa_setup")

      post "#{base}/auth/sign-in", params: { client_id: native_app.uid, email: "totp@acme.com", password: "correct horse battery staple" }, as: :json
      expect(response.parsed_body).to include("challenge" => "otp", "mfa_methods" => [ "otp" ])
    end

    it "sets up a passkey on hosted login, then carries on to the app" do
      end_user = create(:end_user, project: project, email: "new@acme.com")
      app_client = create(:app_client, project: project, redirect_uris: [ "https://shop.example.com/callback" ])
      host! "login.acme.com"
      https!
      get "/oauth2/authorize", params: {
        response_type: "code", client_id: app_client.uid, redirect_uri: "https://shop.example.com/callback", scope: "openid",
        code_challenge: pkce_pair.last, code_challenge_method: "S256"
      }
      interaction = Rack::Utils.parse_query(URI.parse(response.location).query)["interaction"]

      post "/oauth2/interactions/#{interaction}/sign-in", params: { email: "new@acme.com", password: "correct horse battery staple" }, as: :json
      challenge = response.parsed_body
      expect(challenge["challenge"]).to eq("passkey_setup")

      post "/oauth2/interactions/#{interaction}/passkey-setup", params: { session: challenge["session"] }, as: :json
      options = response.parsed_body
      credential = WebAuthn::FakeClient.new("https://login.acme.com", encoding: :base64url)
        .create(challenge: options.dig("public_key", "challenge"), rp_id: "login.acme.com", user_verified: true, backup_eligibility: true)
      post "/oauth2/interactions/#{interaction}/respond-to-challenge", params: {
        challenge: "passkey_setup", session: challenge["session"], registration_id: options["registration_id"], credential: credential
      }, as: :json

      expect(response.parsed_body["redirect_to"]).to start_with("https://login.acme.com/oauth2/authorize/resume?ticket=")
      expect(end_user.webauthn_credentials.sole).to have_attributes(rp_id: "login.acme.com", backup_eligible: true)
    end
  end
end
