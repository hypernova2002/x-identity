require "rails_helper"

RSpec.describe ApiResource do
  let(:project) { create(:project) }

  def api(scopes)
    project.api_resources.new(name: "Orders", identifier: "https://orders.example.com", scopes: scopes)
  end

  it "takes a list of named scopes, unique, few and briefly described" do
    expect(api([ { "name" => "orders:read", "description" => "Read orders" } ])).to be_valid

    expect(error_codes(api("orders:read"), :scopes)).to eq([ :invalid_scope_list ])
    expect(error_codes(api([ { "description" => "x" } ]), :scopes)).to eq([ :invalid_scope_list ])
    expect(error_codes(api(Array.new(described_class::MAX_SCOPES + 1) { |i| { "name" => "s#{i}" } }), :scopes)).to eq([ :too_many ])
    expect(error_codes(api([ { "name" => "a b" } ]), :scopes)).to eq([ :invalid_scope_names ])
    expect(error_codes(api([ { "name" => "read" }, { "name" => "read" } ]), :scopes)).to eq([ :duplicate_scope_names ])
    expect(error_codes(api([ { "name" => "read", "description" => "x" * 201 } ]), :scopes)).to eq([ :scope_description_too_long ])
  end

  it "searches by name and identifier only" do
    expect(described_class.ransackable_attributes).to eq(%w[name identifier])
  end
end
