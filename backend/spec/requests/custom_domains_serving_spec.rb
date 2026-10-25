require "rails_helper"

RSpec.describe "Serving a project on its custom domain", type: :request do
  let(:project) { create(:project) }
  let!(:domain) { project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current) }
  let(:issuer) { "https://login.acme.com" }
  let(:redirect_uri) { "https://shop.example.com/callback" }
  let(:app_client) { create(:app_client, project: project, redirect_uris: [ redirect_uri ]) }
  let!(:end_user) { create(:end_user, project: project, email: "casey@shop.test") }
  let(:verifier_and_challenge) { pkce_pair }

  before do
    host! "login.acme.com"
    https!
  end

  def claims(token)
    JWT.decode(token, nil, false).first
  end

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  # Starts an authorization on the custom domain and signs in on its hosted page; returns the code.
  def code_for_app(scope: "openid email offline_access")
    get "/oauth2/authorize", params: {
      response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: scope, state: "s",
      code_challenge: verifier_and_challenge.last, code_challenge_method: "S256"
    }
    expect(response.location).to start_with("#{issuer}/login?interaction=")

    interaction = query_of(response.location)["interaction"]
    post "/oauth2/interactions/#{interaction}/sign-in", params: { email: "casey@shop.test", password: "correct horse battery staple" }, as: :json
    resume_url = response.parsed_body["redirect_to"]
    expect(resume_url).to start_with("#{issuer}/oauth2/authorize/resume?ticket=")

    get URI.parse(resume_url).request_uri
    expect(response.headers["Set-Cookie"]).to match(/path=\/;/i)
    expect(query_of(response.location)).to include("iss" => issuer, "state" => "s")
    query_of(response.location)["code"]
  end

  it "publishes discovery and keys at the domain's root, with the domain as issuer" do
    get "/.well-known/openid-configuration"

    expect(response.parsed_body).to include(
      "issuer" => issuer, "authorization_endpoint" => "#{issuer}/oauth2/authorize", "token_endpoint" => "#{issuer}/oauth2/token",
      "jwks_uri" => "#{issuer}/.well-known/jwks.json"
    )
    get "/.well-known/jwks.json"
    expect(response.parsed_body).to have_key("keys")
  end

  it "tells hosted pages which project they belong to" do
    get "/auth/domain"

    expect(response.parsed_body).to eq(
      "account_uid" => project.account.uid, "account_slug" => project.account.slug, "account_name" => project.account.name,
      "project_uid" => project.uid, "project_name" => project.name, "issuer" => issuer
    )
  end

  it "runs the whole code flow on the domain, and tokens keep its issuer through refreshes" do
    code = code_for_app

    post "/oauth2/token", params: {
      grant_type: "authorization_code", client_id: app_client.uid, code: code, code_verifier: verifier_and_challenge.first, redirect_uri: redirect_uri
    }
    tokens = response.parsed_body
    expect(claims(tokens["id_token"])["iss"]).to eq(issuer)
    expect(claims(tokens["access_token"])["iss"]).to eq(issuer)

    # The app can refresh on the standard URLs too; the tokens stay the domain's.
    host! URI.parse(Rails.configuration.x.app_base_url).host
    post "#{URI.parse(project.token_issuer).path}/oauth2/token", params: { grant_type: "refresh_token", client_id: app_client.uid, refresh_token: tokens["refresh_token"] }
    expect(claims(response.parsed_body["access_token"])["iss"]).to eq(issuer)

    get "#{URI.parse(project.token_issuer).path}/oauth2/userinfo", headers: { "Authorization" => "Bearer #{response.parsed_body['access_token']}" }
    expect(response).to have_http_status(:ok)
  end

  it "issues the domain's issuer through the sign-in API too" do
    post "/auth/sign-in", params: { client_id: app_client.uid, email: "casey@shop.test", password: "correct horse battery staple" }, as: :json

    expect(claims(response.parsed_body["access_token"])["iss"]).to eq(issuer)
    expect(RefreshToken.last.issuer).to eq(issuer)
  end

  it "keeps the standard issuer for flows on the standard URLs" do
    host! URI.parse(Rails.configuration.x.app_base_url).host
    post "#{URI.parse(project.token_issuer).path}/auth/sign-in", params: { client_id: app_client.uid, email: "casey@shop.test", password: "correct horse battery staple" }, as: :json

    expect(claims(response.parsed_body["access_token"])["iss"]).to eq(project.token_issuer)
    expect(RefreshToken.last.issuer).to be_nil
  end

  it "serves the app portal's settings for the domain" do
    get "/portal"

    expect(response.parsed_body).to include("issuer" => issuer, "redirect_uri" => "#{issuer}/apps", "post_logout_redirect_uri" => "#{issuer}/signed-out")
    expect(project.portal_client!.redirect_uri_allowed?("#{issuer}/apps")).to be(true)
  end

  it "doesn't serve x-identity's own API, or domains that aren't verified or belong to deleted projects" do
    get "/v1/accounts/#{project.account.uid}"
    expect(response).to have_http_status(:not_found)

    domain.update!(status: "pending")
    get "/.well-known/openid-configuration"
    expect(response).to have_http_status(:not_found)

    domain.update!(status: "verified")
    project.update!(deleted_at: Time.current)
    get "/.well-known/openid-configuration"
    expect(response).to have_http_status(:not_found)
  end

  it "links emails to the domain once it's verified" do
    expect(ProjectEndpoints.preferred(project).hosted_page("apps")).to eq("#{issuer}/apps")

    domain.destroy!
    expect(ProjectEndpoints.preferred(project.reload).hosted_page("apps")).to start_with(Rails.configuration.x.console_base_url)
  end
end
