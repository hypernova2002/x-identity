require "rails_helper"
require "openapi_helper"

RSpec.describe "App clients", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the project's app clients" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 200, "app clients" do
          schema type: :array, items: Schemas::AppClient
        end
      end

      post "Create an app client" do
        tags "App clients"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: AppClients::CreateRequest.as_schema } }

        response 201, "created; the secret is only shown now" do
          schema Schemas::AppClientWithSecret
        end

        response 403, "only project admins and developers can manage app clients" do
          schema Schemas::Error
        end

        response 422, "invalid name, type or origins" do
          schema Schemas::Error
        end
      end
    end

    def create_client(user, status, body = { name: "Web shop", client_type: "public", allowed_origins: [ "https://shop.example.com" ] }, &block)
      assert_api_response(:post, status, headers: auth_headers_for(user), body: body, path_params: project_path_params(project), &block)
    end

    it "creates a public client without a secret" do
      create_client(admin, 201) { expect(parsed_body).to include("client_type" => "public", "client_secret" => nil) }
    end

    it "returns a confidential client's secret once" do
      create_client(admin, 201, { name: "Backend", client_type: "confidential" }) do
        expect(AppClient.find_by!(uid: parsed_body["uid"]).authenticate(parsed_body["client_secret"])).to be(true)
      end
    end

    it "lets developers create clients" do
      create_client(developer, 201)
    end

    it "does not let viewers create clients" do
      create_client(viewer, 403)
    end

    it "rejects origins with a path" do
      create_client(admin, 422, { name: "Web", client_type: "public", allowed_origins: [ "https://shop.example.com/app" ] })
    end

    it "registers redirect URIs for identity provider sign-in" do
      body = { name: "Web", client_type: "public", redirect_uris: [ "https://shop.example.com/callback", "com.example.shop:/oauth" ] }

      create_client(admin, 201, body) { expect(parsed_body["redirect_uris"]).to eq(body[:redirect_uris]) }
    end

    it "rejects plain http redirect URIs outside localhost" do
      create_client(admin, 422, { name: "Web", client_type: "public", redirect_uris: [ "http://shop.example.com/callback" ] }) do
        expect(parsed_body.dig("error", "details", 0, "field")).to eq("redirect_uris")
      end
    end

    it "lists the project's clients" do
      create(:app_client, project: project)
      create(:app_client)

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: project_path_params(project)) do
        expect(parsed_body.size).to eq(1)
      end
    end
  end

  describe "a single client" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{uid}/rotate-secret" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      post "Replace a confidential client's secret" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 200, "the new secret; the old one stops working" do
          schema Schemas::AppClientWithSecret
        end

        response 409, "public clients have no secret" do
          schema Schemas::Error
        end
      end
    end

    it "rotates the secret" do
      client = create(:app_client, :confidential, project: project)

      assert_api_response :post, 200, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: client.uid) do
        expect([ client.reload.authenticate("client-secret-for-specs"), client.authenticate(parsed_body["client_secret"]) ]).to eq([ false, true ])
      end
    end

    it "refuses for public clients" do
      client = create(:app_client, project: project)

      assert_api_response :post, 409, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: client.uid)
    end
  end

  it "allows browser requests from a client's origins" do
    create(:app_client, project: project, allowed_origins: [ "https://shop.example.com" ])

    expect(CorsOriginPolicy.new(configured_origins: []).allowed?("https://shop.example.com")).to be(true)
  end
end
