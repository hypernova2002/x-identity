require "rails_helper"
require "openapi_helper"

RSpec.describe "Applications", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
  let!(:web_shop) { create(:app_client, project: project, name: "Web shop") }
  let!(:wiki) { create(:saml_app, project: project, name: "Wiki", enabled: false) }
  let!(:api) { create(:app_client, project: project, name: "Billing API", client_type: "confidential") }

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/applications" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    get "List the project's app clients and SAML apps together" do
      tags "Applications"
      security [ { BearerAuth: [] } ]
      ListParameters.build(
        search: "Name or uid",
        sorts: %w[name type created_at],
        filters: {
          app_type_eq: { type: :string, enum: %w[app_client saml_app] }, kind_eq: { type: :string, enum: %w[oidc machine saml] },
          machine_eq: { type: :string, enum: %w[true false] }, enabled_eq: { type: :string, enum: %w[true false] }
        }
      ).each { |list_parameter| parameter(**list_parameter) }

      response 200, "applications, paginated with Total, Per-Page and Link headers" do
        schema type: :array, items: Schemas::Application
      end

      response 422, "an unsupported sort" do
        schema Schemas::Error
      end
    end
  end

  let(:path_params) { project_path_params(project) }

  it "lists both kinds, sorted by name, without the built-in portal" do
    project.portal_client!

    assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params) do
      expect(parsed_body.map { |row| [ row["app_type"], row["name"] ] }).to eq([ %w[app_client Billing\ API], %w[app_client Web\ shop], %w[saml_app Wiki] ])
      expect(parsed_body.first).to include("uid" => api.uid, "client_type" => "confidential", "entity_id" => nil, "enabled" => true)
      expect(parsed_body.last).to include("uid" => wiki.uid, "entity_id" => wiki.entity_id, "client_type" => nil, "enabled" => false)
    end
  end

  it "searches, filters and sorts in the database" do
    names = lambda do |params|
      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/applications", params: params, headers: auth_headers_for(viewer)
      response.parsed_body.pluck("name")
    end

    expect(names.call(q: { search: "shop" })).to eq([ "Web shop" ])
    expect(names.call(q: { search: wiki.uid })).to eq([ "Wiki" ])
    expect(names.call(q: { app_type_eq: "app_client" })).to eq([ "Billing API", "Web shop" ])
    expect(names.call(q: { enabled_eq: "false" })).to eq([ "Wiki" ])
    expect(names.call(sort: "-name")).to eq([ "Wiki", "Web shop", "Billing API" ])
  end

  it "counts each app's assignments and APIs in the same query" do
    group = project.groups.create!(name: "Staff")
    AppAssignment.create!(project: project, app: wiki, principal: group)
    machine = create(:app_client, :machine, project: project, name: "Billing job")
    machine.api_grants.create!(api_resource: project.api_resources.create!(name: "Orders", identifier: "https://orders.example.com"), scopes: [])

    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/applications", headers: auth_headers_for(viewer)

    counts = response.parsed_body.to_h { |row| [ row["name"], [ row["assignment_count"], row["api_count"] ] ] }
    expect(counts).to include("Wiki" => [ 2, 0 ], "Billing job" => [ 0, 1 ], "Web shop" => [ 1, 0 ])
  end

  it "filters by kind: OpenID Connect, machine-to-machine or SAML" do
    machine = create(:app_client, :machine, project: project, name: "Billing job")
    names = lambda do |kind|
      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/applications", params: { q: { kind_eq: kind } }, headers: auth_headers_for(viewer)
      response.parsed_body.pluck("name")
    end

    expect(names.call("oidc")).to eq([ "Billing API", "Web shop" ])
    expect(names.call("machine")).to eq([ machine.name ])
    expect(names.call("saml")).to eq([ "Wiki" ])
  end

  it "pages across both kinds with a total" do
    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/applications", params: { per_page: 2, page: 2 }, headers: auth_headers_for(viewer)

    expect(response.parsed_body.pluck("name")).to eq([ "Wiki" ])
    expect(response.headers["Total"]).to eq("3")
  end

  it "refuses an unsupported sort" do
    assert_api_response :get, 422, headers: auth_headers_for(viewer), params: { sort: "secret" }, path_params: path_params
  end

  it "only lists the project's own applications" do
    create(:app_client, name: "Elsewhere")

    get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/applications", headers: auth_headers_for(viewer)

    expect(response.parsed_body.pluck("name")).not_to include("Elsewhere")
  end
end
