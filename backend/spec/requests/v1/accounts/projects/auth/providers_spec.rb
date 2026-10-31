require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user sign-in with identity providers", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:redirect_uri) { "https://shop.example.com/auth/callback" }
  let(:app_client) { create(:app_client, project: project, redirect_uris: [ redirect_uri ]) }
  let!(:provider) { create(:identity_provider, project: project) }
  let(:code_verifier_and_challenge) { pkce_pair }
  let(:code_verifier) { code_verifier_and_challenge.first }
  let(:code_challenge) { code_verifier_and_challenge.last }

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  describe "listing providers" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the identity providers end users can sign in with" do
        tags "End-user auth"

        response 200, "enabled providers, for sign-in buttons" do
          schema type: :array, items: Schemas::IdentityProviderSummary
        end
      end
    end

    it "lists only enabled providers" do
      create(:identity_provider, project: project, name: "Old Google", enabled: false)

      assert_api_response(:get, 200, path_params: project_path_params(project)) do
        expect(parsed_body).to eq([ { "uid" => provider.uid, "kind" => "google", "name" => "Google" } ])
      end
    end
  end

  describe "the browser redirect flow" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers/{uid}/authorize" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "Start signing in with an identity provider" do
        tags "End-user auth"
        %w[client_id redirect_uri state code_challenge code_challenge_method].each do |name|
          parameter name: name.to_sym, in: :query, required: true, schema: { type: :string }
        end
        description "Send the user's browser here. They're redirected to the provider, then back to `redirect_uri` " \
          "with `code` and `state`, or with `error`, `error_description` and `state`."

        response 302, "redirect to the provider"

        response 400, "the redirect URI isn't registered for the app client" do
          schema Schemas::Error
        end

        response 401, "unknown or disabled app client" do
          schema Schemas::Error
        end

        response 422, "the code challenge isn't a base64url SHA-256" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers/callback" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "Return from an identity provider" do
        tags "End-user auth"
        %w[state code error].each { |name| parameter name: name.to_sym, in: :query, required: false, schema: { type: :string } }
        description "Register this URL with the provider. Apple returns here with a form POST instead."

        response 303, "redirect to the app with a code, or with an error"

        response 400, "unknown or expired sign-in request" do
          schema Schemas::Error
        end
      end

      post "Return from Apple (form POST)" do
        tags "End-user auth"
        request_body required: true, content: {
          "application/x-www-form-urlencoded" => {
            schema: {
              type: :object,
              properties: {
                state: { type: :string },
                code: { type: :string },
                error: { type: :string },
                user: { type: :string, description: "JSON with the user's name, which Apple only sends on their first sign-in." }
              }
            }
          }
        }

        response 303, "redirect to the app with a code, or with an error"
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers/token" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Exchange the code from an identity provider sign-in" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ProviderTokenRequest.as_schema } }

        response 200, "tokens, or a challenge to answer" do
          schema Schemas::SignInResult
        end

        response 400, "the code is wrong, used or expired, or the code verifier doesn't match" do
          schema Schemas::Error
        end
      end
    end

    def authorize(status = 302, **overrides, &block)
      params = {
        client_id: app_client.uid, redirect_uri: redirect_uri, state: "app-state-1",
        code_challenge: code_challenge, code_challenge_method: "S256"
      }.merge(overrides)
      assert_api_response(:get, status, params: params, path_params: project_path_params(project, uid: provider.uid), &block)
    end

    def return_from_provider(status = 303, **params, &block)
      assert_api_response(:get, status, params: params, path_params: project_path_params(project), &block)
    end

    def redeem(status, **overrides, &block)
      body = { client_id: app_client.uid, code: @app_code, code_verifier: code_verifier, redirect_uri: redirect_uri }.merge(overrides)
      assert_api_response(:post, status, body: body, path_params: project_path_params(project), &block)
    end

    # Runs the flow up to the redirect back to the app, returning that redirect's query.
    def sign_in_through_provider(**claims)
      authorize
      provider_query = query_of(response.location)
      stub_provider_jwks(provider)
      token_stub = stub_provider_token(provider, provider_id_token(provider, nonce: provider_query["nonce"], **claims))
      return_from_provider(state: provider_query["state"], code: "provider-code")
      expect(token_stub).to have_been_requested
      query_of(response.location).tap { |query| @app_code = query["code"] }
    end

    it "sends the user to the provider with PKCE and a nonce" do
      authorize do
        expect(response.location).to start_with("https://accounts.google.com/o/oauth2/v2/auth?")
        expect(query_of(response.location)).to include(
          "client_id" => provider.client_id, "redirect_uri" => provider.callback_url, "response_type" => "code",
          "scope" => "openid email profile", "code_challenge_method" => "S256"
        )
        expect(query_of(response.location).keys).to include("state", "nonce", "code_challenge")
      end
    end

    it "refuses redirect URIs the app client hasn't registered" do
      authorize(400, redirect_uri: "https://evil.example.com/callback") { expect(error_code).to eq("invalid_redirect_uri") }
    end

    it "signs in a new user and returns tokens with the federated amr" do
      app_query = sign_in_through_provider
      expect(app_query["state"]).to eq("app-state-1")

      redeem(200) do
        expect(claims(parsed_body["access_token"])).to include("amr" => [ "fed" ], "aud" => app_client.uid)
        expect(claims(parsed_body["id_token"])).to include("email" => "casey@shop.test", "email_verified" => true)
      end
      expect(project.end_users.sole.identities.sole.subject).to eq("provider-user-1")
    end

    it "sends the user back to the app with an error the app can show" do
      project.update!(allow_self_sign_up: false)

      app_query = sign_in_through_provider

      expect(app_query).to include("error" => "sign_up_disabled", "state" => "app-state-1")
      expect(app_query).not_to have_key("code")
    end

    it "rejects an ID token without the nonce it asked for" do
      authorize
      provider_query = query_of(response.location)
      stub_provider_jwks(provider)
      stub_provider_token(provider, provider_id_token(provider, nonce: "someone-elses-nonce"))

      return_from_provider(state: provider_query["state"], code: "provider-code")

      expect(query_of(response.location)["error"]).to eq("invalid_id_token")
    end

    it "only accepts each provider response once" do
      authorize
      state = query_of(response.location)["state"]
      stub_provider_jwks(provider)
      stub_provider_token(provider, provider_id_token(provider, nonce: query_of(response.location)["nonce"]))
      return_from_provider(state: state, code: "provider-code")

      return_from_provider(400, state: state, code: "provider-code") { expect(error_code).to eq("invalid_state") }
    end

    it "refuses a return without a state, or with one it didn't issue" do
      return_from_provider(400, code: "provider-code") { expect(error_code).to eq("invalid_state") }
      return_from_provider(400, state: "", code: "provider-code") { expect(error_code).to eq("invalid_state") }
      return_from_provider(400, state: "forged", code: "provider-code") { expect(error_code).to eq("invalid_state") }
    end

    it "tells the app when the user cancels at the provider" do
      authorize
      return_from_provider(state: query_of(response.location)["state"], error: "access_denied")

      expect(query_of(response.location)).to include("error" => "identity_provider_error", "state" => "app-state-1")
    end

    it "accepts Apple's form POST, with the name it sends on the first sign-in" do
      apple = create(:identity_provider, :apple, project: project)
      authorize_path = "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/providers/#{apple.uid}/authorize"
      get authorize_path, params: { client_id: app_client.uid, redirect_uri: redirect_uri, state: "s", code_challenge: code_challenge, code_challenge_method: "S256" }
      provider_query = query_of(response.location)
      expect(provider_query).to include("response_mode" => "form_post", "scope" => "name email")
      stub_provider_jwks(apple)
      token_stub = stub_provider_token(apple, provider_id_token(apple, nonce: provider_query["nonce"], name: nil))

      assert_api_response :post, 303, body: { state: provider_query["state"], code: "apple-code", user: { name: { firstName: "Casey", lastName: "Apple" } }.to_json },
        path_params: project_path_params(project), api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers/callback"

      expect(query_of(response.location)).to have_key("code")
      expect(project.end_users.sole.name).to eq("Casey Apple")
      expect(token_stub.with { |request| claims(Rack::Utils.parse_query(request.body)["client_secret"])["iss"] == "TEAM123456" }).to have_been_requested
    end

    it "refuses a code challenge that isn't a base64url SHA-256" do
      authorize(422, code_challenge: "!" * 43) { expect(parsed_body.dig("error", "details", 0)).to include("field" => "code_challenge", "code" => "invalid_code_challenge") }
    end

    it "refuses the return when the app client was disabled meanwhile" do
      authorize
      state = query_of(response.location)["state"]
      app_client.update!(enabled: false)

      return_from_provider(400, state: state, code: "provider-code") { expect(error_code).to eq("invalid_state") }
    end

    it "tells the app when the provider was disabled meanwhile" do
      authorize
      state = query_of(response.location)["state"]
      provider.update!(enabled: false)

      return_from_provider(state: state, code: "provider-code")

      expect(query_of(response.location)).to include("error" => "invalid_state", "state" => "app-state-1")
    end

    it "doesn't redeem a code for a user disabled since" do
      sign_in_through_provider
      project.end_users.sole.update!(status: "disabled")

      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/providers/token",
        params: { client_id: app_client.uid, code: @app_code, code_verifier: code_verifier, redirect_uri: redirect_uri }, as: :json

      expect([ response.status, error_code ]).to eq([ 403, "user_disabled" ])
    end

    it "ignores an Apple user parameter it can't read a name from" do
      apple = create(:identity_provider, :apple, project: project)
      [ "not json", { name: "Casey" }.to_json ].each_with_index do |user, index|
        get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/providers/#{apple.uid}/authorize",
          params: { client_id: app_client.uid, redirect_uri: redirect_uri, state: "s", code_challenge: code_challenge, code_challenge_method: "S256" }
        provider_query = query_of(response.location)
        stub_provider_jwks(apple)
        stub_provider_token(apple, provider_id_token(apple, nonce: provider_query["nonce"], sub: "apple-#{index}", email: "apple#{index}@shop.test", name: nil))

        post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/providers/callback", params: { state: provider_query["state"], code: "apple-code", user: user }

        expect(query_of(response.location)).to have_key("code")
      end
      expect(project.end_users.pluck(:name)).to eq([ nil, nil ])
    end

    it "needs the matching code verifier" do
      sign_in_through_provider

      redeem(400, code_verifier: "x" * 43) { expect(error_code).to eq("invalid_code") }
    end

    it "only redeems the code once" do
      sign_in_through_provider
      redeem(200)

      redeem(400) { expect(error_code).to eq("invalid_code") }
    end

    it "asks for an MFA code when the user has MFA on" do
      create(:end_user, :with_mfa, project: project, email: "casey@shop.test")
      sign_in_through_provider

      redeem(200) { expect(parsed_body).to include("challenge" => "otp") }
    end
  end

  describe "native ID tokens" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/providers/{uid}/id-token" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      post "Sign in with an ID token from a provider's SDK" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ProviderIdTokenRequest.as_schema } }

        response 200, "tokens, or a challenge to answer" do
          schema Schemas::SignInResult
        end

        response 401, "the ID token is invalid, expired, for another app, or has the wrong nonce" do
          schema Schemas::Error
        end

        response 403, "the provider hasn't verified the email, or the user can't be signed in or created" do
          schema Schemas::Error
        end
      end
    end

    let(:nonce) { "nonce-for-specs-123456" }

    before do
      provider.update!(additional_audiences: [ "ios-client-id" ])
      stub_provider_jwks(provider)
    end

    def sign_in_native(status, id_token, nonce: self.nonce, &block)
      body = { client_id: app_client.uid, id_token: id_token, nonce: nonce }
      assert_api_response(:post, status, body: body, path_params: project_path_params(project, uid: provider.uid), &block)
    end

    it "accepts tokens issued to a native app's client id" do
      sign_in_native(200, provider_id_token(provider, aud: "ios-client-id")) { expect(parsed_body).to have_key("access_token") }
    end

    it "accepts Apple-style hashed nonces" do
      sign_in_native(200, provider_id_token(provider, nonce: OpenSSL::Digest::SHA256.hexdigest(nonce)))
    end

    it "rejects tokens for other apps, expired tokens and wrong nonces" do
      sign_in_native(401, provider_id_token(provider, aud: "someone-else")) { expect(error_code).to eq("invalid_id_token") }
      sign_in_native(401, provider_id_token(provider, exp: 1.hour.ago.to_i))
      sign_in_native(401, provider_id_token(provider), nonce: "a-different-nonce-1234")
    end

    it "rejects tokens signed by another key" do
      other_key = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: "provider-key-1")

      sign_in_native(401, provider_id_token(provider, key: other_key))
    end

    it "refuses emails the provider hasn't verified" do
      sign_in_native(403, provider_id_token(provider, email_verified: false)) { expect(error_code).to eq("provider_email_unverified") }
    end
  end
end
