require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user sessions", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, project: project) }
  let(:tokens) { tokens_for(end_user, app_client: app_client) }
  let(:path_params) { project_path_params(project) }

  describe "refreshing" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/refresh" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Exchange a refresh token for new tokens" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::RefreshRequest.as_schema } }

        response 200, "new tokens" do
          schema Schemas::TokenSet
        end

        response 401, "invalid, reused or expired refresh token, or wrong app client" do
          schema Schemas::Error
        end
      end
    end

    def refresh(status, client = app_client, token = tokens.refresh_token, &block)
      assert_api_response(:post, status, body: { client_id: client.uid, refresh_token: token }, path_params: path_params, &block)
    end

    it "rotates the refresh token" do
      refresh(200) { expect(parsed_body.keys).to include("id_token") }
    end

    it "only works with the app client the token was issued to" do
      refresh(401, create(:app_client, project: project))
    end

    it "rejects console refresh tokens" do
      console_tokens = tokens_for(create(:user, account: project.account))

      refresh(401, app_client, console_tokens.refresh_token)
    end

    it "stops working once the app client is disabled" do
      tokens
      AppClients::Management.new(actor: create(:user, :admin, account: project.account), project: project).update(app_client, enabled: false)

      refresh(401)
    end
  end

  describe "signing out" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/sign-out" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Revoke the session behind a refresh token" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::SignOutRequest.as_schema } }

        response 204, "signed out"
      end
    end

    it "revokes the session" do
      assert_api_response :post, 204, body: { client_id: app_client.uid, refresh_token: tokens.refresh_token }, path_params: path_params

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end
  end

  describe "JWKS" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/.well-known/jwks.json" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "Public keys for verifying the project's tokens" do
        tags "End-user auth"

        response 200, "JSON Web Key Set" do
          schema type: :object, required: %w[keys], properties: { keys: { type: :array, items: { type: :object } } }
        end
      end
    end

    it "publishes the project's signing key" do
      kid = JWT.decode(tokens.access_token, nil, false).last["kid"]

      assert_api_response(:get, 200, path_params: path_params) { expect(parsed_body["keys"].pluck("kid")).to eq([ kid ]) }
    end
  end
end
