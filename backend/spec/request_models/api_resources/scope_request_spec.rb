require "rails_helper"

RSpec.describe ApiResources::ScopeRequest do
  let(:valid_body) { { name: "orders:read" } }

  it_behaves_like "a required field", :name
  it_behaves_like "a scope name field", :name

  it_behaves_like "an optional field", :description
  it_behaves_like "a string field", :description, min: 1, max: 200, nullable: true
end
