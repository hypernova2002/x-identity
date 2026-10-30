require "rails_helper"

RSpec.describe ApiResources::CreateRequest do
  let(:valid_body) { { name: "Orders", identifier: "https://orders.shop.test" } }

  it_behaves_like "api resource fields", required: %i[name]

  it_behaves_like "a required field", :identifier
  it_behaves_like "a string field", :identifier, min: 3, max: 255
end
