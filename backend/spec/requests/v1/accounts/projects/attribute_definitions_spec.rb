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
      ListParameters.build(search: "Key or label", sorts: %w[label key data_type created_at], filters: { data_type_eq: { type: :string }, required_eq: { type: :string, enum: %w[true false] }, user_editable_eq: { type: :string, enum: %w[true false] }, include_in_token_eq: { type: :string, enum: %w[true false] } }).each { |list_parameter| parameter(**list_parameter) }

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

  describe "one attribute" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/attributes/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Change a custom end-user attribute" do
        tags "End-user attributes"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: AttributeDefinitions::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::AttributeDefinition
        end

        response 403, "only project admins can change attributes" do
          schema Schemas::Error
        end

        response 422, "invalid settings, e.g. a maximum length for an attribute that isn't a string" do
          schema Schemas::Error
        end
      end

      delete "Delete a custom end-user attribute and every end user's value for it" do
        tags "End-user attributes"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"

        response 403, "only project admins can delete attributes" do
          schema Schemas::Error
        end
      end
    end

    let(:item_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/attributes/{uid}" }
    let(:definition) { create(:end_user_attribute_definition, project: project, key: "tier", label: "Tier") }

    it "lets admins change an attribute" do
      assert_api_response(:patch, 200, headers: auth_headers_for(admin), body: { label: "Loyalty tier", user_editable: false },
        path_params: project_path_params(project, uid: definition.uid), api_path: item_path) do
        expect(parsed_body).to include("label" => "Loyalty tier", "user_editable" => false)
      end
    end

    it "doesn't let developers change or delete attributes" do
      path_params = project_path_params(project, uid: definition.uid)

      assert_api_response :patch, 403, headers: auth_headers_for(developer), body: { label: "Loyalty tier" }, path_params: path_params, api_path: item_path
      assert_api_response :delete, 403, headers: auth_headers_for(developer), path_params: path_params, api_path: item_path
    end

    it "refuses a maximum length for attributes that aren't strings" do
      number = create(:end_user_attribute_definition, project: project, key: "seats", data_type: "number")

      assert_api_response :patch, 422, headers: auth_headers_for(admin), body: { max_length: 10 },
        path_params: project_path_params(project, uid: number.uid), api_path: item_path
    end

    it "removes the value from every end user when deleted" do
      end_user = create(:end_user, project: project, custom_attributes: { "tier" => "gold", "other" => "kept" })

      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: definition.uid), api_path: item_path

      expect(end_user.reload.custom_attributes).to eq("other" => "kept")
    end
  end

  describe "searching, filtering and sorting" do
    def keys(params)
      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/attributes", params: params, headers: auth_headers_for(admin)
      response.parsed_body.pluck("key")
    end

    before do
      create(:end_user_attribute_definition, project: project, key: "tier", label: "Plan tier", required: true)
      create(:end_user_attribute_definition, project: project, key: "region", label: "Region", data_type: "string", include_in_token: true)
    end

    it "searches keys and labels, filters by flags and sorts" do
      expect(keys(q: { search: "plan" })).to eq([ "tier" ])
      expect(keys(q: { required_eq: "true" })).to eq([ "tier" ])
      expect(keys(q: { include_in_token_eq: "true" })).to eq([ "region" ])
      expect(keys(sort: "label")).to eq(%w[tier region])
      expect(keys(sort: "-key")).to eq(%w[tier region])
    end
  end
end
