require "rails_helper"

RSpec.describe ApiGrant do
  let(:project) { create(:project) }
  let(:api) { project.api_resources.create!(name: "Orders", identifier: "https://orders.example.com", scopes: [ { "name" => "orders:read" } ]) }
  let(:machine) { create(:app_client, :machine, project: project) }

  it "is for a machine app of the API's project, with scopes the API defines" do
    expect(described_class.new(app_client: machine, api_resource: api, scopes: [ "orders:read" ])).to be_valid

    grant = described_class.new(app_client: create(:app_client, project: project), api_resource: api, scopes: [])
    expect(error_codes(grant, :app_client)).to eq([ :not_machine_app ])
    expect(error_codes(described_class.new(api_resource: api, scopes: []), :app_client)).to include(:not_machine_app)
    expect(error_codes(described_class.new(app_client: create(:app_client, :machine), api_resource: api, scopes: []), :api_resource)).to eq([ :other_project ])
  end

  it "takes a list of the API's scope names" do
    expect(error_codes(described_class.new(app_client: machine, api_resource: api, scopes: "orders:read"), :scopes)).to eq([ :invalid_scope_name_list ])
    expect(error_codes(described_class.new(app_client: machine, api_resource: api, scopes: [ "orders:write" ]), :scopes)).to eq([ :undefined_scopes ])
    expect(error_codes(described_class.new(app_client: machine, scopes: [ "orders:read" ]), :scopes)).to eq([ :undefined_scopes ])
  end
end
