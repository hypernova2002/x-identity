require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user attributes", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/attributes" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    get "List the project's custom end-user attributes" do
      tags "End-user attributes"
      security [ { BearerAuth: [] } ]

      response 200, "attributes" do
        schema type: :array, items: Schemas::AttributeDefinition
      end
    end

    post "Define a custom end-user attribute" do
      tags "End-user attributes"
      security [ { BearerAuth: [] } ]
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: AttributeDefinitions::CreateRequest.as_schema } }

      response 201, "created" do
        schema Schemas::AttributeDefinition
      end

      response 403, "only project admins can define attributes" do
        schema Schemas::Error
      end

      response 422, "invalid or reserved key" do
        schema Schemas::Error
      end
    end
  end

  let(:path_params) { project_path_params(project) }

  it "creates an attribute" do
    assert_api_response :post, 201, headers: auth_headers_for(admin),
      body: { key: "loyalty_tier", label: "Loyalty tier", data_type: "string", required: false, max_length: 20 }, path_params: path_params
  end

  it "refuses reserved keys" do
    assert_api_response :post, 422, headers: auth_headers_for(admin), body: { key: "email", label: "Email", data_type: "string" }, path_params: path_params
  end

  it "does not let developers define attributes" do
    assert_api_response :post, 403, headers: auth_headers_for(developer), body: { key: "tier", label: "Tier", data_type: "string" }, path_params: path_params
  end

  it "removes the value from every end user when deleted" do
    definition = create(:end_user_attribute_definition, project: project, key: "tier")
    end_user = create(:end_user, project: project, custom_attributes: { "tier" => "gold", "other" => "kept" })

    delete "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/attributes/#{definition.uid}", headers: auth_headers_for(admin)

    expect(end_user.reload.custom_attributes).to eq("other" => "kept")
  end
end
