require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user profile", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, project: project, name: "Casey") }
  let(:tokens) { tokens_for(end_user, app_client: app_client) }
  let(:headers) { { "Authorization" => "Bearer #{tokens.access_token}" } }
  let(:path_params) { project_path_params(project) }

  describe "profile" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "The signed-in end user" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 200, "the end user" do
          schema Schemas::EndUser
        end

        response 401, "missing or invalid access token" do
          schema Schemas::Error
        end
      end

      patch "Update your name and user-editable attributes" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserMe::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::EndUser
        end

        response 422, "invalid name or attributes" do
          schema Schemas::Error
        end
      end
    end

    it "returns the end user" do
      assert_api_response(:get, 200, headers: headers, path_params: path_params) { expect(parsed_body["uid"]).to eq(end_user.uid) }
    end

    it "rejects the ID token in place of the access token" do
      assert_api_response :get, 401, headers: { "Authorization" => "Bearer #{tokens.id_token}" }, path_params: path_params
    end

    it "rejects console access tokens" do
      assert_api_response :get, 401, headers: auth_headers_for(create(:user, account: project.account)), path_params: path_params
    end

    it "rejects tokens from another project of the same account" do
      other_project = create(:project, account: project.account)
      other_tokens = tokens_for(create(:end_user, project: other_project), app_client: create(:app_client, project: other_project))

      assert_api_response :get, 401, headers: { "Authorization" => "Bearer #{other_tokens.access_token}" }, path_params: path_params
    end

    it "rejects tokens once their app client is disabled" do
      headers
      app_client.update!(enabled: false)

      assert_api_response :get, 401, headers: headers, path_params: path_params
    end

    it "saves the end user's language" do
      assert_api_response(:patch, 200, headers: headers, body: { locale: "ja" }, path_params: path_params) do
        expect(parsed_body["locale"]).to eq("ja")
      end
      expect(end_user.reload.locale).to eq("ja")
    end

    context "with attributes" do
      before do
        create(:end_user_attribute_definition, project: project, key: "nickname")
        create(:end_user_attribute_definition, project: project, key: "tier", user_editable: false)
      end

      it "updates user-editable attributes" do
        assert_api_response :patch, 200, headers: headers, body: { custom_attributes: { nickname: "Cas" } }, path_params: path_params do
          expect(parsed_body["custom_attributes"]).to eq("nickname" => "Cas")
        end
      end

      it "refuses attributes only admins can change" do
        assert_api_response :patch, 422, headers: headers, body: { custom_attributes: { tier: "gold" } }, path_params: path_params
      end
    end
  end

  describe "email change" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/email/confirm" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm a new email with the code sent to it" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserMe::ConfirmEmailChangeRequest.as_schema } }

        response 200, "email changed" do
          schema Schemas::EndUser
        end

        response 400, "wrong or expired code" do
          schema Schemas::Error
        end
      end
    end

    let!(:issued) { OneTimeToken.issue_with_code!(subject: end_user, purpose: :email_change, data: { "new_email" => "new@shop.test" }) }

    it "changes the email with the code" do
      assert_api_response :post, 200, headers: headers, body: { code: issued.code }, path_params: path_params do
        expect(parsed_body["email"]).to eq("new@shop.test")
      end
    end

    it "rejects a wrong code" do
      assert_api_response :post, 400, headers: headers, body: { code: "000000" }, path_params: path_params
    end
  end
end
