require "rails_helper"
require "openapi_helper"

RSpec.describe "Project audit log", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/audit-events" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    get "List the project's audit events, newest first" do
      tags "Audit log"
      security [ { BearerAuth: [] } ]
      parameter name: :q, in: :query, style: :deepObject, explode: true, schema: {
        type: :object,
        properties: {
          action_eq: { type: :string },
          action_start: { type: :string },
          actor_uid_eq: { type: :string },
          target_uid_eq: { type: :string },
          app_client_uid_eq: { type: :string },
          occurred_at_gteq: { type: :string, format: "date-time" },
          occurred_at_lteq: { type: :string, format: "date-time" }
        }
      }

      response 200, "audit events" do
        schema type: :array, items: Schemas::AuditEvent
      end

      response 403, "only project admins and developers can read the log" do
        schema Schemas::Error
      end
    end
  end

  let(:project) { create(:project) }
  let(:path_params) { project_path_params(project) }

  def member(role)
    create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: role) }
  end

  before do
    project.realm.recorder.record(action: "end_user.signed_in")
    project.account.realm.recorder.record(action: "user.signed_in")
    create(:project, account: project.account).realm.recorder.record(action: "end_user.signed_in")
  end

  it "shows only this project's events" do
    assert_api_response(:get, 200, headers: auth_headers_for(member("developer")), path_params: path_params) do
      expect(parsed_body.pluck("action")).to eq([ "end_user.signed_in" ])
    end
  end

  it "is readable by project admins" do
    assert_api_response :get, 200, headers: auth_headers_for(member("admin")), path_params: path_params
  end

  it "is hidden from viewers" do
    assert_api_response :get, 403, headers: auth_headers_for(member("viewer")), path_params: path_params
  end
end
