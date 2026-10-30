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
      ListParameters.build(search: "Action prefix, e.g. `end_user.`", sorts: %w[occurred_at], filters: { action_eq: { type: :string }, action_start: { type: :string }, actor_uid_eq: { type: :string }, target_uid_eq: { type: :string }, app_client_uid_eq: { type: :string }, saml_app_uid_eq: { type: :string }, occurred_at_gteq: { type: :string, format: "date-time" }, occurred_at_lteq: { type: :string, format: "date-time" } }, capped: true).each { |list_parameter| parameter(**list_parameter) }

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

  it "filters by the SAML app an event was about" do
    wiki = create(:saml_app, project: project)
    project.realm.recorder.record(action: "end_user.signed_in_to_app", saml_app: wiki)

    assert_api_response(:get, 200, headers: auth_headers_for(member("developer")), params: { q: { saml_app_uid_eq: wiki.uid } }, path_params: path_params) do
      expect(parsed_body.sole).to include("action" => "end_user.signed_in_to_app", "saml_app_uid" => wiki.uid)
    end
  end

  it "caps the total on large logs, and counts exactly when asked" do
    stub_const("Paginated::COUNT_CAP", 3)
    5.times { project.realm.recorder.record(action: "end_user.signed_in") }
    headers = auth_headers_for(member("developer"))

    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/audit-events", params: { per_page: 2 }, headers: headers
    expect([ response.headers["Total"], response.headers["Total-Capped"], response.parsed_body.size ]).to eq([ "3", "true", 2 ])

    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/audit-events", params: { per_page: 2, exact_count: "true" }, headers: headers
    expect([ response.headers["Total"], response.headers["Total-Capped"] ]).to eq([ "6", nil ])
  end

  it "keeps counting past the cap far enough to page on" do
    stub_const("Paginated::COUNT_CAP", 3)
    9.times { project.realm.recorder.record(action: "end_user.signed_in") }

    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/audit-events", params: { per_page: 2, page: 4 },
      headers: auth_headers_for(member("developer"))

    expect(response.parsed_body.size).to eq(2)
    expect([ response.headers["Total"], response.headers["Total-Capped"] ]).to eq([ "8", "true" ])
  end

  it "refuses pages past the last one it serves" do
    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/audit-events", params: { page: Paginated::MAX_PAGE + 1 },
      headers: auth_headers_for(member("developer"))

    expect([ response.status, response.parsed_body.dig("error", "details", 0, "field") ]).to eq([ 422, "page" ])
  end

  it "is readable by project admins" do
    assert_api_response :get, 200, headers: auth_headers_for(member("admin")), path_params: path_params
  end

  it "is hidden from viewers" do
    assert_api_response :get, 403, headers: auth_headers_for(member("viewer")), path_params: path_params
  end
end
