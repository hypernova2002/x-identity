require "rails_helper"
require "openapi_helper"

RSpec.describe "Machine-to-machine apps", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
  let(:orders) do
    project.api_resources.create!(
      name: "Orders", identifier: "https://orders.example.com",
      scopes: [ { "name" => "orders:read" }, { "name" => "orders:write" }, { "name" => "orders:delete" } ]
    )
  end
  let(:billing) { create(:app_client, :machine, project: project, name: "Billing job") }

  def token(client: billing, secret: "client-secret-for-specs", **params)
    post "#{URI.parse(project.token_issuer).path}/oauth2/token",
      params: { grant_type: "client_credentials", **params },
      headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(client.uid, secret) }
    response.parsed_body
  end

  def claims(jwt)
    JWT.decode(jwt, nil, false).first
  end

  describe "the client_credentials grant" do
    before { billing.api_grants.create!(api_resource: orders, scopes: %w[orders:read orders:write]) }

    it "issues a short-lived token for the API with the requested scopes" do
      body = token(audience: orders.identifier, scope: "orders:read")

      expect(response).to have_http_status(:ok)
      expect(body).to include("token_type" => "Bearer", "expires_in" => 900, "scope" => "orders:read")
      expect(body).not_to have_key("refresh_token")
      expect(claims(body["access_token"])).to include(
        "iss" => project.token_issuer, "sub" => billing.uid, "client_id" => billing.uid, "aud" => "https://orders.example.com",
        "scope" => "orders:read", "gty" => "client-credentials", "token_use" => "access"
      )
    end

    it "grants everything allowed when no scope is asked for, and finds the app's only API without an audience" do
      expect(token).to include("scope" => "orders:read orders:write")
    end

    it "uses the API's own token lifetime" do
      orders.update!(access_token_ttl_seconds: 300)

      expect(token(audience: orders.identifier)["expires_in"]).to eq(300)
    end

    it "is verifiable with the project's published keys" do
      access_token = token(audience: orders.identifier)["access_token"]
      kid = JWT.decode(access_token, nil, false).last["kid"]
      key = project.signing_keys.published.find_by!(kid: kid)

      verified, = JWT.decode(access_token, key.verification_key, true, algorithm: key.algorithm, aud: orders.identifier, verify_aud: true)
      expect(verified["sub"]).to eq(billing.uid)
    end

    it "refuses scopes that weren't granted, and APIs the app has no access to" do
      expect(token(audience: orders.identifier, scope: "orders:delete")).to include("error" => "invalid_scope")
      other = project.api_resources.create!(name: "Stock", identifier: "https://stock.example.com")
      expect(token(audience: other.identifier)).to include("error" => "invalid_target")
      expect(token(audience: "https://nowhere.example.com")).to include("error" => "invalid_target")
    end

    it "needs an audience when the app may use several APIs" do
      billing.api_grants.create!(api_resource: project.api_resources.create!(name: "Stock", identifier: "https://stock.example.com"), scopes: [])

      expect(token).to include("error" => "invalid_request")
    end

    it "refuses a wrong secret, and disabled apps" do
      expect(token(audience: orders.identifier, secret: "wrong")).to include("error" => "invalid_client")
      billing.update!(enabled: false)
      expect(token(audience: orders.identifier)).to include("error" => "invalid_client")
    end

    it "is only for machine-to-machine apps, which can't use the other grants" do
      web = create(:app_client, :confidential, project: project, redirect_uris: [ "https://shop.example.com/cb" ])
      expect(token(audience: orders.identifier, client: web)).to include("error" => "unauthorized_client")

      post "#{URI.parse(project.token_issuer).path}/oauth2/token", params: { grant_type: "refresh_token", refresh_token: "x" },
        headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(billing.uid, "client-secret-for-specs") }
      expect(response.parsed_body).to include("error" => "unauthorized_client")
    end

    it "audits every token issued and every refusal" do
      token(audience: orders.identifier, scope: "orders:read")
      token(audience: orders.identifier, scope: "orders:delete")

      expect(AuditEvent.order(:id).last(2).map { |event| [ event.action, event.app_client_uid, event.metadata["scope"] || event.metadata["error"] ] })
        .to eq([ [ "app_client.token_issued", billing.uid, "orders:read" ], [ "app_client.token_refused", billing.uid, "invalid_scope" ] ])
    end

    it "keeps working with the previous secret while a rotated secret takes over" do
      new_secret = billing.rotate_secret!

      expect(token(audience: orders.identifier, secret: "client-secret-for-specs")).to have_key("access_token")
      expect(token(audience: orders.identifier, secret: new_secret)).to have_key("access_token")
    end
  end

  describe "rate limits and rotation settings" do
    before { billing.api_grants.create!(api_resource: orders, scopes: %w[orders:read]) }

    it "limits token requests per client per minute to the project's setting" do
      project.auth_configuration!.update!(token_requests_per_minute: 10)

      10.times { token }
      body = token

      expect(response).to have_http_status(:too_many_requests)
      expect(body).to include("error" => "slow_down")
      expect(response.headers["Retry-After"].to_i).to be_between(1, 60)
      expect(AuditEvent.last).to have_attributes(action: "app_client.token_refused", metadata: include("error" => "slow_down", "limit" => 10))
    end

    it "lets an app have its own limit, and starts counting again each minute" do
      project.auth_configuration!.update!(token_requests_per_minute: 10)
      billing.update!(token_requests_per_minute: 12)

      freeze_time do
        12.times { token }
        expect(token).to include("error" => "slow_down")
      end
      travel 1.minute do
        expect(token).to have_key("access_token")
      end
    end

    it "keeps previous secrets working for the project's rotation overlap" do
      project.auth_configuration!.update!(client_secret_rotation_overlap_seconds: 1.hour.to_i)
      billing.rotate_secret!

      travel 59.minutes do
        expect(billing.authenticate("client-secret-for-specs")).to be(true)
      end
      travel 61.minutes do
        expect(billing.authenticate("client-secret-for-specs")).to be(false)
      end
    end

    it "stops previous secrets at once when the overlap is 0" do
      project.auth_configuration!.update!(client_secret_rotation_overlap_seconds: 0)
      new_secret = billing.rotate_secret!

      expect([ billing.authenticate("client-secret-for-specs"), billing.authenticate(new_secret) ]).to eq([ false, true ])
    end

    it "doesn't extend an earlier secret's end date when rotating again" do
      billing.rotate_secret!
      first = billing.secrets.order(:created_at).first
      ends = first.reload.expires_at

      travel 1.day do
        billing.rotate_secret!
        expect(first.reload.expires_at).to eq(ends)
      end
    end
  end

  describe "keeping machine apps out of user sign-in" do
    let(:access_token) do
      billing.api_grants.create!(api_resource: orders, scopes: [])
      token(audience: orders.identifier)["access_token"]
    end

    it "refuses their tokens on end-user endpoints, even with an API named like an app client" do
      project.api_resources.create!(name: "Tricky", identifier: create(:app_client, project: project).uid)
        .then { |api| billing.api_grants.create!(api_resource: api, scopes: []) }
      tricky = token(audience: project.api_resources.find_by!(name: "Tricky").identifier)["access_token"]

      [ access_token, tricky ].each do |jwt|
        get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/me", headers: { "Authorization" => "Bearer #{jwt}" }
        expect(response).to have_http_status(:unauthorized)
        get "#{URI.parse(project.token_issuer).path}/oauth2/userinfo", headers: { "Authorization" => "Bearer #{jwt}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "doesn't let them sign end users in" do
      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/sign-in",
        params: { client_id: billing.uid, client_secret: "client-secret-for-specs", email: "casey@shop.test", password: "x" }, as: :json
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_client")

      get "#{URI.parse(project.token_issuer).path}/oauth2/authorize", params: { client_id: billing.uid, response_type: "code" }
      expect(response.location.to_s).to include("error")
    end

    it "advertises the grant in discovery" do
      get "#{URI.parse(project.token_issuer).path}/.well-known/openid-configuration"

      expect(response.parsed_body["grant_types_supported"]).to include("client_credentials")
    end
  end

  describe "APIs" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/apis" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the project's APIs" do
        tags "APIs"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Name or identifier", sorts: %w[name identifier created_at]).each { |list_parameter| parameter(**list_parameter) }

        response 200, "APIs" do
          schema type: :array, items: Schemas::ApiResource
        end
      end

      post "Add an API" do
        tags "APIs"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ApiResources::CreateRequest.as_schema } }

        response 201, "created" do
          schema Schemas::ApiResource
        end

        response 403, "only project admins and developers can manage APIs" do
          schema Schemas::Error
        end

        response 422, "invalid identifier or scopes" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { project_path_params(project) }

    it "creates APIs with their scopes, with identifiers unique in the project" do
      body = { name: "Orders", identifier: "https://orders.example.com", scopes: [ { name: "orders:read", description: "Read orders" } ] }

      assert_api_response(:post, 201, headers: auth_headers_for(developer), body: body, path_params: path_params) do
        expect(parsed_body).to include("identifier" => "https://orders.example.com", "scopes" => [ { "name" => "orders:read", "description" => "Read orders" } ])
      end
      assert_api_response :post, 422, headers: auth_headers_for(developer), body: body, path_params: path_params
    end

    it "refuses scope names it can't put in a token" do
      assert_api_response :post, 422, headers: auth_headers_for(developer), body: { name: "Orders", identifier: "https://o.example.com", scopes: [ { name: "read orders" } ] },
        path_params: path_params
    end

    it "lists APIs for viewers, who can't change them" do
      orders

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params) do
        expect(parsed_body.sole).to include("name" => "Orders", "app_count" => 0)
      end
      assert_api_response :post, 403, headers: auth_headers_for(viewer), body: { name: "X", identifier: "https://x.example.com" }, path_params: path_params
    end
  end

  describe "one API" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/apis/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "An API" do
        tags "APIs"
        security [ { BearerAuth: [] } ]

        response 200, "the API" do
          schema Schemas::ApiResource
        end
      end

      patch "Change an API's name, scopes or token lifetime" do
        tags "APIs"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ApiResources::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::ApiResource
        end
      end

      delete "Delete an API; apps lose access" do
        tags "APIs"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"
      end
    end

    let(:path_params) { project_path_params(project, uid: orders.uid) }

    it "takes removed scopes out of every app's grant" do
      grant = billing.api_grants.create!(api_resource: orders, scopes: %w[orders:read orders:write])

      assert_api_response :patch, 200, headers: auth_headers_for(developer), body: { scopes: [ { name: "orders:read" } ] }, path_params: path_params

      expect(grant.reload.scopes).to eq([ "orders:read" ])
    end

    it "deletes the API and its grants" do
      billing.api_grants.create!(api_resource: orders, scopes: [])

      assert_api_response :delete, 204, headers: auth_headers_for(developer), path_params: path_params

      expect(billing.api_grants.reload).to be_empty
    end
  end

  describe "an app's API access" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{app_client_uid}/api-grants" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :app_client_uid, in: :path, required: true, schema: { type: :string }

      get "List the APIs a machine-to-machine app may get tokens for" do
        tags "APIs"
        security [ { BearerAuth: [] } ]

        response 200, "grants" do
          schema type: :array, items: Schemas::ApiGrant
        end
      end

      post "Let a machine-to-machine app get tokens for an API" do
        tags "APIs"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ApiGrants::CreateRequest.as_schema } }

        response 201, "granted" do
          schema Schemas::ApiGrant
        end

        response 422, "not a machine-to-machine app, already granted, or scopes the API doesn't define" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { project_path_params(project, app_client_uid: billing.uid) }

    it "grants an API's scopes to a machine app" do
      assert_api_response(:post, 201, headers: auth_headers_for(developer), body: { api_uid: orders.uid, scopes: [ "orders:read" ] }, path_params: path_params) do
        expect(parsed_body).to include("api_identifier" => "https://orders.example.com", "scopes" => [ "orders:read" ])
      end
      assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: path_params) do
        expect(parsed_body.sole["api_uid"]).to eq(orders.uid)
      end
    end

    it "refuses scopes the API doesn't define, and apps that aren't machine apps" do
      assert_api_response :post, 422, headers: auth_headers_for(developer), body: { api_uid: orders.uid, scopes: [ "admin" ] }, path_params: path_params

      web = create(:app_client, :confidential, project: project)
      assert_api_response :post, 422, headers: auth_headers_for(developer), body: { api_uid: orders.uid, scopes: [] },
        path_params: project_path_params(project, app_client_uid: web.uid)
    end
  end

  describe "secrets" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{app_client_uid}/secrets" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :app_client_uid, in: :path, required: true, schema: { type: :string }

      get "List a confidential client's secrets" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 200, "secrets, newest first; only their last four characters are shown" do
          schema type: :array, items: Schemas::AppClientSecret
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{app_client_uid}/secrets/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :app_client_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Revoke a secret now" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 204, "revoked"

        response 409, "the client's only working secret" do
          schema Schemas::Error
        end
      end
    end

    it "lists both secrets after a rotation, and revokes the old one" do
      billing.rotate_secret!
      old = billing.secrets.order(:created_at).first

      assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: project_path_params(project, app_client_uid: billing.uid)) do
        expect(parsed_body.map { |secret| secret["usable"] }).to eq([ true, true ])
        expect(parsed_body.last["expires_at"]).to be_present
      end
      assert_api_response :delete, 204, headers: auth_headers_for(developer), path_params: project_path_params(project, app_client_uid: billing.uid, uid: old.uid)

      expect(billing.authenticate("client-secret-for-specs")).to be(false)
    end

    it "won't revoke the only working secret" do
      assert_api_response :delete, 409, headers: auth_headers_for(developer),
        path_params: project_path_params(project, app_client_uid: billing.uid, uid: billing.secrets.sole.uid)
    end
  end
end
