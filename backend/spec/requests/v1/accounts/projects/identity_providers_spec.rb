require "rails_helper"
require "openapi_helper"

RSpec.describe "Identity providers", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/identity-providers" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the project's identity providers" do
        tags "Identity providers"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Name", sorts: %w[name kind created_at], filters: { kind_eq: { type: :string }, kind_in: { type: :array, items: { type: :string } }, enabled_eq: { type: :string, enum: %w[true false] } }).each { |list_parameter| parameter(**list_parameter) }

        response 200, "identity providers, without their secrets" do
          schema type: :array, items: Schemas::IdentityProvider
        end
      end

      post "Add an identity provider" do
        tags "Identity providers"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: IdentityProviders::CreateRequest.as_schema } }

        response 201, "created" do
          schema Schemas::IdentityProvider
        end

        response 403, "only project admins can manage identity providers" do
          schema Schemas::Error
        end

        response 422, "invalid settings, or the discovery document couldn't be loaded" do
          schema Schemas::Error
        end
      end
    end

    def create_provider(user, status, body, &block)
      assert_api_response(:post, status, headers: auth_headers_for(user), body: body, path_params: project_path_params(project), &block)
    end

    it "adds Google without returning the secret" do
      create_provider(admin, 201, { kind: "google", name: "Google", client_id: "web.apps.googleusercontent.com", client_secret: "shh" }) do
        expect(parsed_body).to include("kind" => "google", "issuer" => "https://accounts.google.com", "client_secret_set" => true)
        expect(parsed_body["callback_url"]).to eq("#{project.token_issuer}/auth/providers/callback")
        expect(response.body).not_to include("shh")
      end
    end

    it "loads a generic OIDC provider's endpoints from its discovery document" do
      stub_discovery("https://login.example.com")

      create_provider(admin, 201, { kind: "oidc", name: "Example SSO", client_id: "x", client_secret: "y", discovery_url: "https://login.example.com" }) do
        expect(IdentityProvider.last.metadata).to include("token_endpoint" => "https://login.example.com/token", "jwks_uri" => "https://login.example.com/jwks")
      end
    end

    it "rejects a discovery document whose issuer doesn't match" do
      stub_discovery("https://login.example.com", issuer: "https://evil.example.com")

      create_provider(admin, 422, { kind: "oidc", name: "Example SSO", client_id: "x", client_secret: "y", discovery_url: "https://login.example.com" }) do
        expect(parsed_body.dig("error", "details", 0, "field")).to eq("discovery_url")
      end
    end

    it "adds Apple with its signing key" do
      key = OpenSSL::PKey::EC.generate("prime256v1").to_pem
      body = { kind: "apple", name: "Apple", client_id: "com.example.shop.web", apple_team_id: "TEAM123456", apple_key_id: "KEY1234567", apple_private_key: key }

      create_provider(admin, 201, body) { expect(parsed_body).to include("apple_private_key_set" => true, "client_secret_set" => false) }
    end

    it "is only for project admins" do
      create_provider(developer, 403, { kind: "google", name: "Google", client_id: "web", client_secret: "shh" })
    end

    it "records the change in the audit log" do
      create_provider(admin, 201, { kind: "google", name: "Google", client_id: "web", client_secret: "shh" })

      expect(AuditEvent.last).to have_attributes(action: "identity_provider.created", project_id: project.id)
    end
  end

  describe "a provider" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/identity-providers/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Change an identity provider" do
        tags "Identity providers"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: IdentityProviders::UpdateRequest.as_schema } }

        response 200, "updated; blank secrets keep the current ones" do
          schema Schemas::IdentityProvider
        end

        response 422, "invalid settings" do
          schema Schemas::Error
        end
      end

      delete "Remove an identity provider and unlink its users" do
        tags "Identity providers"
        security [ { BearerAuth: [] } ]

        response 204, "removed"
      end
    end

    let!(:provider) { create(:identity_provider, project: project, client_secret: "original-secret") }
    let(:path_params) { project_path_params(project, uid: provider.uid) }

    it "keeps the secret when it's left blank" do
      assert_api_response(:patch, 200, headers: auth_headers_for(admin), body: { name: "Google Workspace", client_secret: "" }, path_params: path_params)

      expect(provider.reload).to have_attributes(name: "Google Workspace", client_secret: "original-secret")
    end

    it "doesn't put secrets in the audit log" do
      assert_api_response(:patch, 200, headers: auth_headers_for(admin), body: { client_secret: "new-secret" }, path_params: path_params)

      expect(AuditEvent.last.metadata).to eq("changes" => { "client_secret" => "changed" })
    end

    it "unlinks every user when deleted" do
      create(:end_user_identity, identity_provider: provider, end_user: create(:end_user, project: project))

      assert_api_response(:delete, 204, headers: auth_headers_for(admin), path_params: path_params)

      expect(EndUserIdentity.count).to eq(0)
    end
  end

  describe "searching, filtering and sorting providers" do
    def names(params)
      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/identity-providers", params: params, headers: auth_headers_for(developer)
      response.parsed_body.pluck("name")
    end

    before do
      create(:identity_provider, project: project)
      create(:identity_provider, :saml, project: project, enabled: false)
    end

    it "filters by kind and status, and sorts" do
      expect(names(q: { kind_eq: "saml" })).to eq([ "Acme SSO" ])
      expect(names(q: { kind_in: %w[google apple] })).to eq([ "Google" ])
      expect(names(q: { enabled_eq: "false" })).to eq([ "Acme SSO" ])
      expect(names(q: { search: "goo" })).to eq([ "Google" ])
      expect(names(sort: "-name")).to eq([ "Google", "Acme SSO" ])
    end
  end
end
