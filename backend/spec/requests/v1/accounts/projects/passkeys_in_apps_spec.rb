require "rails_helper"
require "openapi_helper"

RSpec.describe "Passkeys in an app's own sign-in screen", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let!(:domain) { project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current) }
  let(:app_client) { create(:app_client, project: project, allowed_origins: [ "https://app.acme.com" ]) }
  let(:end_user) { create(:end_user, project: project, email: "casey@acme.com") }
  let(:path_params) { project_path_params(project) }
  let(:base) { URI.parse(project.token_issuer).path }

  before { project.auth_configuration!.update!(passkeys: "optional") }

  let(:authenticator) { WebAuthn::FakeAuthenticator.new }

  # The browser on a page at the origin, with the same authenticator (and so the same passkeys).
  def browser_at(origin)
    WebAuthn::FakeClient.new(origin, encoding: :base64url, authenticator: authenticator)
  end

  # Adds a passkey for login.acme.com on the domain's own pages.
  def add_domain_passkey
    relying_party = Passkeys::RelyingParties.for(end_user, endpoints: ProjectEndpoints.new(project, domain: domain))
    add_passkey(end_user, relying_party: relying_party, origin: "https://login.acme.com", client: browser_at("https://login.acme.com"))
  end

  def options_for(path, **params)
    post path, params: { client_id: app_client.uid, **params }, as: :json
    response.parsed_body
  end

  describe "the custom domain's related origins" do
    it "lists the project's apps' allowed origins, so browsers let them use its passkeys" do
      app_client
      create(:app_client, project: project, allowed_origins: [ "https://shop.acme.co.uk", "https://login.acme.com" ])
      create(:app_client, project: project, enabled: false, allowed_origins: [ "https://old.acme.com" ])
      host! "login.acme.com"
      https!

      get "/.well-known/webauthn"

      expect(response.parsed_body).to eq("origins" => [ "https://app.acme.com", "https://shop.acme.co.uk" ])
      expect(response.headers["Cache-Control"]).to include("public")
    end

    it "lists nothing while passkeys are off" do
      app_client
      project.auth_configuration!.update!(passkeys: "off")
      host! "login.acme.com"

      get "/.well-known/webauthn"

      expect(response.parsed_body).to eq("origins" => [])
    end
  end

  describe "signing in" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey/options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Start a passkey sign-in from the app's own screen" do
        tags "End-user authentication"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::PasskeyOptionsRequest.as_schema } }

        response 200, "options for navigator.credentials.get, for the project's custom domain's passkeys" do
          schema type: :object, required: %w[authentication_id public_key]
        end

        response 409, "passkeys are off, the project has no custom domain, or the app has no allowed origins" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Sign in with the passkey the browser chose" do
        tags "End-user authentication"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::PasskeySignInRequest.as_schema } }

        response 200, "tokens, or a challenge" do
          schema Schemas::SignInResult
        end

        response 400, "the passkey couldn't be verified, e.g. the page isn't on one of the app's allowed origins" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/respond-to-challenge/passkey-options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Options for answering a second-factor challenge with a passkey" do
        tags "End-user authentication"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::PasskeyChallengeOptionsRequest.as_schema } }

        response 200, "options allowing only the user's own passkeys" do
          schema type: :object, required: %w[authentication_id public_key]
        end
      end
    end

    it "signs in with a domain passkey from the app's allowed origin" do
      add_domain_passkey
      app_page = browser_at("https://app.acme.com")
      options = nil
      assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey/options", path_params: path_params, body: { client_id: app_client.uid }) do
        options = parsed_body
        expect(parsed_body.dig("public_key", "rpId")).to eq("login.acme.com")
      end

      body = { client_id: app_client.uid, authentication_id: options["authentication_id"], credential: passkey_answer(app_page, options, user: end_user, rp_id: "login.acme.com") }
      assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey", path_params: path_params, body: body) do
        expect(JWT.decode(parsed_body["access_token"], nil, false).first).to include("amr" => %w[hwk user], "aud" => app_client.uid)
      end
    end

    it "refuses answers from pages on other origins" do
      add_domain_passkey
      elsewhere = browser_at("https://evil.example.com")
      options = options_for("#{base}/auth/passkey/options")

      post "#{base}/auth/passkey", params: {
        client_id: app_client.uid, authentication_id: options["authentication_id"], credential: passkey_answer(elsewhere, options, user: end_user, rp_id: "login.acme.com")
      }, as: :json
      expect(error_code).to eq("invalid_passkey")
    end

    it "isn't available to apps without allowed origins" do
      app_client.update!(allowed_origins: [])

      assert_api_response :post, 409, api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/auth/passkey/options", path_params: path_params, body: { client_id: app_client.uid }
    end

    it "answers a second-factor challenge through the API" do
      end_user = create(:end_user, :with_mfa, project: project, email: "both@acme.com")
      client = add_passkey(end_user, relying_party: Passkeys::RelyingParties.for(end_user, app_client: app_client), origin: "https://app.acme.com")

      post "#{base}/auth/sign-in", params: { client_id: app_client.uid, email: "both@acme.com", password: "correct horse battery staple" }, as: :json
      challenge = response.parsed_body
      expect(challenge).to include("challenge" => "otp", "mfa_methods" => %w[otp passkey])

      options = nil
      assert_api_response(:post, 200, api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/auth/respond-to-challenge/passkey-options",
        path_params: path_params, body: { client_id: app_client.uid, session: challenge["session"] }) { options = parsed_body }
      post "#{base}/auth/respond-to-challenge", params: {
        client_id: app_client.uid, challenge: "passkey", session: challenge["session"], authentication_id: options["authentication_id"],
        credential: passkey_answer(client, options, user: end_user, rp_id: "login.acme.com")
      }, as: :json

      expect(JWT.decode(response.parsed_body["access_token"], nil, false).first["amr"]).to eq(%w[pwd hwk user])
    end

    it "doesn't offer passkeys as a second factor to apps without allowed origins" do
      end_user = create(:end_user, :with_mfa, project: project, email: "both@acme.com")
      add_passkey(end_user, relying_party: Passkeys::RelyingParties.for(end_user, app_client: app_client), origin: "https://app.acme.com")
      native = create(:app_client, project: project)

      post "#{base}/auth/sign-in", params: { client_id: native.uid, email: "both@acme.com", password: "correct horse battery staple" }, as: :json

      expect(response.parsed_body).to include("challenge" => "otp", "mfa_methods" => %w[otp])
    end
  end

  describe "adding passkeys from the app" do
    it "adds a domain passkey from the app's allowed origin, with the app's access token" do
      headers = { "Authorization" => "Bearer #{tokens_for(end_user, app_client: app_client).access_token}" }

      post "#{base}/me/passkeys/options", headers: headers
      options = response.parsed_body
      expect(options.dig("public_key", "rp", "id")).to eq("login.acme.com")
      credential = WebAuthn::FakeClient.new("https://app.acme.com", encoding: :base64url)
        .create(challenge: options.dig("public_key", "challenge"), rp_id: "login.acme.com", user_verified: true)
      post "#{base}/me/passkeys", params: { registration_id: options["registration_id"], credential: credential }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(end_user.webauthn_credentials.sole.rp_id).to eq("login.acme.com")
    end
  end
end
