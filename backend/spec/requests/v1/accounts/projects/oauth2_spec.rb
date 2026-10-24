require "rails_helper"
require "openapi_helper"

RSpec.describe "OpenID Connect provider", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:redirect_uri) { "https://shop.example.com/callback" }
  let(:app_client) do
    create(:app_client, project: project, redirect_uris: [ redirect_uri ], post_logout_redirect_uris: [ "https://shop.example.com/signed-out" ])
  end
  let!(:end_user) { create(:end_user, project: project, email: "casey@shop.test") }
  let(:verifier_and_challenge) { pkce_pair }
  let(:code_verifier) { verifier_and_challenge.first }
  let(:code_challenge) { verifier_and_challenge.last }
  let(:hosted_base) { "#{Rails.configuration.x.console_base_url}/auth/#{project.account.slug}/#{project.uid}" }

  # Cookies are kept per host, so every request goes to the issuer's host.
  before { host! URI.parse(Rails.configuration.x.app_base_url).then { |uri| "#{uri.host}:#{uri.port}" } }

  def oauth_path(path)
    "#{URI.parse(project.token_issuer).path}/oauth2/#{path}"
  end

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  def authorize_params(**overrides)
    {
      response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid email",
      state: "app-state", nonce: "app-nonce", code_challenge: code_challenge, code_challenge_method: "S256"
    }.merge(overrides).compact
  end

  def authorize(**overrides)
    get oauth_path("authorize"), params: authorize_params(**overrides)
    expect(response).to have_http_status(:found)
    response.location
  end

  # Starts an authorization and signs in on the hosted page, returning where the page sends the browser.
  def sign_in_on_hosted_page(password: "correct horse battery staple", **authorize_overrides)
    interaction = query_of(authorize(**authorize_overrides))["interaction"]
    post oauth_path("interactions/#{interaction}/sign-in"), params: { email: "casey@shop.test", password: password }, as: :json
    response.parsed_body
  end

  # The browser follows the page's redirect_to back to the issuer, which redirects to the app.
  def follow(url)
    get URI.parse(url).request_uri
    response.location
  end

  def code_for_app(**authorize_overrides)
    query_of(follow(sign_in_on_hosted_page(**authorize_overrides)["redirect_to"]))["code"]
  end

  def exchange(code, **overrides)
    post oauth_path("token"), params: { grant_type: "authorization_code", client_id: app_client.uid, code: code, code_verifier: code_verifier, redirect_uri: redirect_uri }.merge(overrides)
  end

  describe "discovery" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/.well-known/openid-configuration" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "OpenID Connect discovery document" do
        tags "OpenID Connect"

        response 200, "the provider's endpoints and capabilities" do
          schema type: :object, required: %w[issuer authorization_endpoint token_endpoint jwks_uri]
        end
      end
    end

    it "describes the project's endpoints under its issuer" do
      assert_api_response(:get, 200, path_params: project_path_params(project)) do
        expect(parsed_body).to include(
          "issuer" => project.token_issuer,
          "authorization_endpoint" => "#{project.token_issuer}/oauth2/authorize",
          "jwks_uri" => "#{project.token_issuer}/.well-known/jwks.json",
          "code_challenge_methods_supported" => [ "S256" ]
        )
      end
    end
  end

  describe "the authorization code flow" do
    it "sends a browser without a session to the hosted login page" do
      expect(authorize).to start_with("#{hosted_base}/login?interaction=")
    end

    it "shows the hosted page what it needs" do
      create(:identity_provider, project: project)
      interaction = query_of(authorize(login_hint: "casey@shop.test"))["interaction"]

      get oauth_path("interactions/#{interaction}")

      expect(response.parsed_body).to include("app_name" => app_client.name, "project_name" => project.name, "login_hint" => "casey@shop.test")
      expect(response.parsed_body["identity_providers"].sole).to include("kind" => "google")
    end

    it "signs in on the hosted page, starts a session and sends the app a code" do
      result = sign_in_on_hosted_page
      expect(result.keys).to eq([ "redirect_to" ])

      app_redirect = follow(result["redirect_to"])

      expect(app_redirect).to start_with("#{redirect_uri}?")
      expect(query_of(app_redirect)).to include("state" => "app-state", "iss" => project.token_issuer)
      expect(response.cookies[BrowserSession::COOKIE_NAME]).to be_present
      expect(BrowserSession.sole).to have_attributes(end_user: end_user, amr: [ "pwd" ])
    end

    it "exchanges the code for tokens carrying the nonce, without a refresh token unless asked" do
      exchange(code_for_app)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.parsed_body).to include("token_type" => "Bearer", "scope" => "openid email")
      expect(response.parsed_body).not_to have_key("refresh_token")
      expect(claims(response.parsed_body["id_token"])).to include("nonce" => "app-nonce", "aud" => app_client.uid, "sub" => end_user.uid)
    end

    it "adds the user's groups to the ID token and userinfo for the groups scope" do
      exchange(code_for_app(scope: "openid groups"))
      token = response.parsed_body

      expect(claims(token["id_token"])["groups"]).to eq([ "All end users" ])
      get oauth_path("userinfo"), headers: { "Authorization" => "Bearer #{token['access_token']}" }
      expect(response.parsed_body["groups"]).to eq([ "All end users" ])
    end

    it "refuses an SSO sign-in to an app the user isn't assigned to" do
      follow(sign_in_on_hosted_page["redirect_to"])
      other = create(:app_client, project: project, redirect_uris: [ "https://other.example.com/cb" ], assigned_to_everyone: false)

      location = authorize(client_id: other.uid, redirect_uri: "https://other.example.com/cb")

      expect(query_of(location)).to include("error" => "access_denied")
    end

    it "issues a refresh token for offline_access, which the token endpoint can refresh" do
      exchange(code_for_app(scope: "openid offline_access"))
      refresh_token = response.parsed_body.fetch("refresh_token")

      post oauth_path("token"), params: { grant_type: "refresh_token", client_id: app_client.uid, refresh_token: refresh_token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["refresh_token"]).not_to eq(refresh_token)
    end

    it "puts every app the browser signs in to under the browser's device" do
      exchange(code_for_app(scope: "openid offline_access"))
      device = BrowserSession.sole.device_session

      expect(RefreshToken.find_by_token(response.parsed_body["refresh_token"]).device_session).to eq(device)
      expect(claims(response.parsed_body["access_token"])["sid"]).to eq(device.uid)
    end

    it "doesn't redeem a code for a device that was signed out since" do
      code = code_for_app
      BrowserSession.sole.device_session.revoke!

      exchange(code)

      expect(response.parsed_body).to include("error" => "invalid_grant")
    end

    it "needs the right code verifier, and each code only once" do
      code = code_for_app

      exchange(code, code_verifier: "x" * 43)
      expect(response.parsed_body).to include("error" => "invalid_grant")

      exchange(code)
      expect(response).to have_http_status(:ok)

      exchange(code)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "authenticates confidential clients with Basic credentials" do
      app_client.update!(client_type: "confidential")
      _record, secret = AppClientSecret.issue!(app_client)
      code = code_for_app

      exchange(code)
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("invalid_client")

      post oauth_path("token"), params: { grant_type: "authorization_code", code: code, code_verifier: code_verifier, redirect_uri: redirect_uri },
        headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{app_client.uid}:#{secret}")}" }
      expect(response).to have_http_status(:ok)
    end

    it "asks for an MFA code on the hosted page, through the interaction only" do
      user = create(:end_user, :with_mfa, project: project, email: "mfa@shop.test")
      interaction = query_of(authorize)["interaction"]
      post oauth_path("interactions/#{interaction}/sign-in"), params: { email: "mfa@shop.test", password: "correct horse battery staple" }, as: :json
      challenge = response.parsed_body
      expect(challenge["challenge"]).to eq("otp")

      post "#{URI.parse(project.token_issuer).path}/auth/respond-to-challenge",
        params: { client_id: app_client.uid, challenge: "otp", session: challenge["session"], code: current_totp_for(user) }, as: :json
      expect(error_code).to eq("invalid_challenge")

      post oauth_path("interactions/#{interaction}/respond-to-challenge"),
        params: { challenge: "otp", session: challenge["session"], code: current_totp_for(user) }, as: :json
      expect(response.parsed_body["redirect_to"]).to include("/oauth2/authorize/resume?ticket=")
    end

    it "reports wrong passwords to the page" do
      result = sign_in_on_hosted_page(password: "wrong")

      expect(result.dig("error", "code")).to eq("invalid_credentials")
    end

    it "rejects expired interactions" do
      interaction = query_of(authorize)["interaction"]

      travel 31.minutes do
        get oauth_path("interactions/#{interaction}")
      end

      expect(error_code).to eq("invalid_interaction")
    end
  end

  describe "authorization errors" do
    it "shows unknown clients and unregistered redirect URIs on the hosted error page" do
      expect(authorize(client_id: "cl_unknown")).to start_with("#{hosted_base}/error?")
      expect(authorize(redirect_uri: "https://evil.example.com/callback")).to start_with("#{hosted_base}/error?")
    end

    it "sends other errors back to the app" do
      expect(query_of(authorize(code_challenge: nil))).to include("error" => "invalid_request", "state" => "app-state")
      expect(query_of(authorize(scope: "email"))).to include("error" => "invalid_scope")
      expect(query_of(authorize(response_type: "token"))).to include("error" => "unsupported_response_type")
    end

    it "answers prompt=none with login_required when there's no session" do
      expect(query_of(authorize(prompt: "none"))).to include("error" => "login_required", "state" => "app-state")
    end
  end

  describe "single sign-on" do
    before { follow(sign_in_on_hosted_page["redirect_to"]) }

    it "signs the browser in to another app without the hosted page" do
      other_app = create(:app_client, project: project, redirect_uris: [ "https://admin.example.com/callback" ])

      location = authorize(client_id: other_app.uid, redirect_uri: "https://admin.example.com/callback", prompt: "none")

      expect(query_of(location)).to have_key("code")
      expect(AuditEvent.last).to have_attributes(action: "end_user.signed_in", app_client_uid: other_app.uid)
    end

    it "asks again for prompt=login, or when the sign-in is older than max_age" do
      expect(authorize(prompt: "login")).to start_with("#{hosted_base}/login?")

      travel 2.minutes do
        expect(authorize(max_age: "60")).to start_with("#{hosted_base}/login?")
      end
    end

    it "ends when the user's sessions are revoked" do
      end_user.revoke_all_sessions!

      expect(authorize).to start_with("#{hosted_base}/login?")
    end

    it "ends at logout, returning to a registered post-logout address" do
      get oauth_path("logout"), params: { client_id: app_client.uid, post_logout_redirect_uri: "https://shop.example.com/signed-out", state: "bye" }

      expect(response).to have_http_status(:see_other)
      expect(response.location).to eq("https://shop.example.com/signed-out?state=bye")
      expect(BrowserSession.sole.revoked_at).to be_present
      expect(authorize).to start_with("#{hosted_base}/login?")
    end

    it "doesn't send users to unregistered post-logout addresses" do
      get oauth_path("logout"), params: { client_id: app_client.uid, post_logout_redirect_uri: "https://evil.example.com/" }

      expect(response.location).to start_with("#{hosted_base}/error?")
    end
  end

  describe "userinfo and revocation" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/oauth2/userinfo" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "Claims about the signed-in end user" do
        tags "OpenID Connect"
        security [ { BearerAuth: [] } ]

        response 200, "the user's claims" do
          schema type: :object, required: %w[sub]
        end
      end
    end

    it "returns the user's claims for an access token" do
      exchange(code_for_app)
      headers = { "Authorization" => "Bearer #{response.parsed_body['access_token']}" }

      assert_api_response(:get, 200, headers: headers, path_params: project_path_params(project)) do
        expect(parsed_body).to include("sub" => end_user.uid, "email" => "casey@shop.test", "email_verified" => true)
      end
    end

    it "revokes refresh tokens" do
      exchange(code_for_app(scope: "openid offline_access"))
      refresh_token = response.parsed_body["refresh_token"]

      post oauth_path("revoke"), params: { client_id: app_client.uid, token: refresh_token }
      expect(response).to have_http_status(:ok)

      post oauth_path("token"), params: { grant_type: "refresh_token", client_id: app_client.uid, refresh_token: refresh_token }
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end
  end

  describe "sign-up and password reset on the hosted page" do
    include ActiveJob::TestHelper

    let(:interaction) { query_of(authorize)["interaction"] }

    it "signs up through the interaction without revealing whether the email exists" do
      expect do
        post oauth_path("interactions/#{interaction}/sign-up"), params: { email: "new@shop.test", password: "correct horse battery staple" }, as: :json
      end.to have_enqueued_job(EndUserSignUpJob).with(hash_including(email: "new@shop.test", app_client_id: app_client.id))
      expect(response).to have_http_status(:accepted)
    end

    it "refuses sign-up when the project doesn't allow it" do
      project.update!(allow_self_sign_up: false)

      post oauth_path("interactions/#{interaction}/sign-up"), params: { email: "new@shop.test", password: "correct horse battery staple" }, as: :json

      expect(error_code).to eq("sign_up_disabled")
    end

    it "resets a password with the emailed code" do
      perform_enqueued_jobs do
        post oauth_path("interactions/#{interaction}/forgot-password"), params: { email: "casey@shop.test" }, as: :json
      end
      expect(response).to have_http_status(:accepted)

      post oauth_path("interactions/#{interaction}/confirm-forgot-password"),
        params: { email: "casey@shop.test", code: last_code_sent_to("casey@shop.test"), password: "a brand new password" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Passwords::Hasher.new.matches?("a brand new password", end_user.reload.password_digest)).to be(true)
    end
  end

  describe "identity providers on the hosted page" do
    let!(:provider) { create(:identity_provider, project: project) }

    it "signs in through the provider and returns to the authorization" do
      interaction = query_of(authorize)["interaction"]
      get oauth_path("interactions/#{interaction}/providers/#{provider.uid}")
      provider_query = query_of(response.location)
      expect(response.location).to start_with("https://accounts.google.com/")

      stub_provider_jwks(provider)
      stub_provider_token(provider, provider_id_token(provider, nonce: provider_query["nonce"], sub: "google-1"))
      get "#{URI.parse(project.token_issuer).path}/auth/providers/callback", params: { state: provider_query["state"], code: "google-code" }

      expect(response.location).to include("/oauth2/authorize/resume?ticket=")
      expect(query_of(follow(response.location))).to have_key("code")
      expect(BrowserSession.sole.amr).to eq([ "fed" ])
    end
  end
end
