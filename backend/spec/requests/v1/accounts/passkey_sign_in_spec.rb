require "rails_helper"
require "openapi_helper"

RSpec.describe "Signing in with a passkey", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, email: "casey@acme.test") }
  let(:console) { URI.parse(Rails.configuration.x.console_base_url) }
  let(:console_origin) { "#{console.scheme}://#{console.host}:#{console.port}" }
  let(:relying_party) { Passkeys::RelyingParties.console(account) }
  let(:path_params) { { account_uid: account.uid } }

  before { account.auth_configuration!.update!(passkeys: "optional") }

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  def passkey_options(path = "/v1/accounts/#{account.uid}/auth/passkey/options", **params)
    post path, params: params, as: :json
    response.parsed_body
  end

  describe "the console" do
    api_path "/v1/accounts/{account_uid}/auth/passkey/options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Start a passkey sign-in" do
        tags "Authentication"

        response 200, "options for navigator.credentials.get; any of the user's passkeys for the console can answer" do
          schema type: :object, required: %w[authentication_id public_key]
        end

        response 409, "passkeys aren't turned on for console users" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/auth/passkey" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Sign in with the passkey the browser chose" do
        tags "Authentication"
        request_body required: true, content: { "application/json" => { schema: Passkeys::SignInRequest.as_schema } }

        response 200, "tokens, or a challenge such as new_password" do
          schema Schemas::SignInResult
        end

        response 400, "the passkey couldn't be verified" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/auth/respond-to-challenge/passkey-options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Options for answering a second-factor challenge with a passkey" do
        tags "Authentication"
        request_body required: true, content: { "application/json" => { schema: Passkeys::ChallengeOptionsRequest.as_schema } }

        response 200, "options allowing only the user's own passkeys; answer with respond-to-challenge, challenge: passkey" do
          schema type: :object, required: %w[authentication_id public_key]
        end
      end
    end

    it "signs in with a passkey alone, which counts as multi-factor" do
      client = add_passkey(user, relying_party: relying_party, origin: console_origin, synced: true)
      options = nil
      assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/auth/passkey/options", path_params: path_params) do
        options = parsed_body
        expect(parsed_body.dig("public_key", "allowCredentials")).to eq([])
        expect(parsed_body.dig("public_key", "userVerification")).to eq("required")
      end

      body = { authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: user, rp_id: console.host) }
      assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/auth/passkey", path_params: path_params, body: body) do
        expect(claims(parsed_body["access_token"])["amr"]).to eq(%w[swk user])
      end
      expect(user.webauthn_credentials.sole.last_used_at).to be_present
      expect(AuditEvent.last).to have_attributes(action: "user.signed_in", metadata: include("amr" => %w[swk user]))
    end

    it "refuses passkeys the user didn't unlock, counting them towards the lockout" do
      client = add_passkey(user, relying_party: relying_party, origin: console_origin)
      options = passkey_options
      body = { authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: user, rp_id: console.host, user_verified: false) }

      assert_api_response :post, 400, api_path: "/v1/accounts/{account_uid}/auth/passkey", path_params: path_params, body: body
      expect(Rails.configuration.x.counter_store.read(Auth::Lockout.new(owner: account, configuration: account.auth_configuration!).send(:failures_key, user.email)).to_i).to eq(1)
    end

    it "refuses another account's passkeys and answers used twice" do
      other_user = create(:user, email: "other@acme.test")
      other_user.account.auth_configuration!.update!(passkeys: "optional")
      client = add_passkey(other_user, relying_party: Passkeys::RelyingParties.console(other_user.account), origin: console_origin)
      options = passkey_options
      post "/v1/accounts/#{account.uid}/auth/passkey", params: { authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: other_user, rp_id: console.host) }, as: :json
      expect(error_code).to eq("invalid_passkey")

      own = add_passkey(user, relying_party: relying_party, origin: console_origin)
      options = passkey_options
      body = { authentication_id: options["authentication_id"], credential: passkey_answer(own, options, user: user, rp_id: console.host) }
      post "/v1/accounts/#{account.uid}/auth/passkey", params: body, as: :json
      expect(response).to have_http_status(:ok)
      post "/v1/accounts/#{account.uid}/auth/passkey", params: body, as: :json
      expect(error_code).to eq("invalid_passkey")
    end

    it "isn't offered while passkeys are off" do
      account.auth_configuration!.update!(passkeys: "off")

      assert_api_response :post, 409, api_path: "/v1/accounts/{account_uid}/auth/passkey/options", path_params: path_params
    end

    describe "as a second factor" do
      def sign_in_with_password
        post "/v1/accounts/#{account.uid}/auth/sign-in", params: { email: "casey@acme.test", password: "correct horse battery staple" }, as: :json
        response.parsed_body
      end

      it "answers the one-time code challenge for users who have both" do
        user = create(:user, :with_mfa, account: account, email: "both@acme.test")
        client = add_passkey(user, relying_party: relying_party, origin: console_origin)
        post "/v1/accounts/#{account.uid}/auth/sign-in", params: { email: "both@acme.test", password: "correct horse battery staple" }, as: :json
        challenge = response.parsed_body
        expect(challenge).to include("challenge" => "otp", "mfa_methods" => %w[otp passkey])

        options = nil
        assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/auth/respond-to-challenge/passkey-options", path_params: path_params, body: { session: challenge["session"] }) do
          options = parsed_body
          expect(parsed_body.dig("public_key", "allowCredentials").map { |allowed| allowed["id"] }).to eq([ user.webauthn_credentials.sole.external_id ])
        end
        post "/v1/accounts/#{account.uid}/auth/respond-to-challenge", params: {
          challenge: "passkey", session: challenge["session"], authentication_id: options["authentication_id"],
          credential: passkey_answer(client, options, user: user, rp_id: console.host)
        }, as: :json

        expect(claims(response.parsed_body["access_token"])["amr"]).to eq(%w[pwd hwk user])
      end

      it "is required of users with only a passkey when the policy requires MFA, and not otherwise" do
        add_passkey(user, relying_party: relying_party, origin: console_origin)
        expect(sign_in_with_password).to have_key("access_token")

        account.auth_configuration!.update!(mfa_requirement: "required")
        expect(sign_in_with_password).to include("challenge" => "passkey", "mfa_methods" => [ "passkey" ])
      end

      it "satisfies a policy requiring MFA without setting up an authenticator app" do
        account.auth_configuration!.update!(mfa_requirement: "required")
        client = add_passkey(user, relying_party: relying_party, origin: console_origin)
        options = passkey_options

        post "/v1/accounts/#{account.uid}/auth/passkey", params: { authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: user, rp_id: console.host) }, as: :json

        expect(response.parsed_body).to have_key("access_token")
      end
    end
  end

  describe "hosted login on the project's custom domain" do
    let(:project) { create(:project, account: account) }
    let!(:domain) { project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current) }
    let(:redirect_uri) { "https://shop.example.com/callback" }
    let(:app_client) { create(:app_client, project: project, redirect_uris: [ redirect_uri ]) }
    let(:end_user) { create(:end_user, project: project) }
    let(:endpoints) { ProjectEndpoints.new(project, domain: domain) }

    before do
      project.auth_configuration!.update!(passkeys: "optional")
      host! "login.acme.com"
      https!
    end

    def start_interaction
      get "/oauth2/authorize", params: {
        response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid",
        code_challenge: pkce_pair.last, code_challenge_method: "S256"
      }
      Rack::Utils.parse_query(URI.parse(response.location).query)["interaction"]
    end

    it "signs in with a passkey on the hosted page" do
      client = add_passkey(end_user, relying_party: Passkeys::RelyingParties.for(end_user, endpoints: endpoints), origin: "https://login.acme.com")
      interaction = start_interaction

      get "/oauth2/interactions/#{interaction}"
      expect(response.parsed_body["passkeys"]).to be(true)

      options = passkey_options("/oauth2/interactions/#{interaction}/passkey/options")
      post "/oauth2/interactions/#{interaction}/passkey", params: {
        authentication_id: options["authentication_id"], credential: passkey_answer(client, options, user: end_user, rp_id: "login.acme.com")
      }, as: :json

      expect(response.parsed_body["redirect_to"]).to start_with("https://login.acme.com/oauth2/authorize/resume?ticket=")
    end

    it "isn't offered on the standard URLs" do
      host! URI.parse(Rails.configuration.x.app_base_url).host
      https!(false)
      get "#{URI.parse(project.token_issuer).path}/oauth2/authorize", params: {
        response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid", code_challenge: pkce_pair.last, code_challenge_method: "S256"
      }
      interaction = Rack::Utils.parse_query(URI.parse(response.location).query)["interaction"]

      get "#{URI.parse(project.token_issuer).path}/oauth2/interactions/#{interaction}"
      expect(response.parsed_body["passkeys"]).to be(false)
      post "#{URI.parse(project.token_issuer).path}/oauth2/interactions/#{interaction}/passkey/options"
      expect(error_code).to eq("passkeys_unavailable")
    end

    it "lets admins see and remove an end user's passkeys, and counts them on the domain" do
      add_passkey(end_user, relying_party: Passkeys::RelyingParties.for(end_user, endpoints: endpoints), origin: "https://login.acme.com")
      admin = create(:user, :admin, account: account)
      host! URI.parse(Rails.configuration.x.app_base_url).host
      https!(false)
      base = "/v1/accounts/#{account.uid}/projects/#{project.uid}"

      get "#{base}/domains", headers: auth_headers_for(admin)
      expect(response.parsed_body.sole["passkey_count"]).to eq(1)

      get "#{base}/end-users/#{end_user.uid}/passkeys", headers: auth_headers_for(admin)
      passkey_uid = response.parsed_body.sole["uid"]
      delete "#{base}/end-users/#{end_user.uid}/passkeys/#{passkey_uid}", headers: auth_headers_for(admin)

      expect(response).to have_http_status(:no_content)
      expect(end_user.webauthn_credentials.reload).to be_empty
      expect(AuditEvent.last).to have_attributes(action: "end_user.passkey_removed", actor_uid: admin.uid)
    end
  end
end
