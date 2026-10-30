require "rails_helper"
require "openapi_helper"

RSpec.describe "Project auth configuration", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth-configuration" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    get "The project's end-user authentication settings" do
      tags "Auth configuration"
      security [ { BearerAuth: [] } ]

      response 200, "current settings" do
        schema Schemas::AuthConfiguration
      end
    end

    put "Update the project's end-user authentication settings" do
      tags "Auth configuration"
      security [ { BearerAuth: [] } ]
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: AuthConfigurations::UpdateRequest.as_schema } }

      response 200, "updated" do
        schema Schemas::AuthConfiguration
      end

      response 403, "only project admins can change settings" do
        schema Schemas::Error
      end

      response 422, "a setting is out of range" do
        schema Schemas::Error
      end
    end
  end

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:path_params) { project_path_params(project) }

  it "shows the settings to everyone in the project" do
    assert_api_response :get, 200, headers: auth_headers_for(developer), path_params: path_params do
      expect(parsed_body).to include("mfa_requirement" => "optional")
    end
  end

  it "lets admins change the settings, and records it" do
    assert_api_response :put, 200, headers: auth_headers_for(admin), body: { mfa_requirement: "required", lockout_threshold: 5 }, path_params: path_params

    expect(project.auth_configuration!.reload).to have_attributes(mfa_requirement: "required", lockout_threshold: 5)
    expect(AuditEvent.last.metadata.dig("changes", "lockout_threshold")).to eq({ "from" => 10, "to" => 5 })
  end

  it "doesn't let developers change the settings" do
    assert_api_response :put, 403, headers: auth_headers_for(developer), body: { lockout_threshold: 5 }, path_params: path_params
  end

  it "rejects out-of-range values" do
    assert_api_response :put, 422, headers: auth_headers_for(admin), body: { access_token_ttl_seconds: 2.hours.to_i }, path_params: path_params
  end
end
