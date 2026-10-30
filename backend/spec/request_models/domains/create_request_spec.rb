require "rails_helper"

RSpec.describe Domains::CreateRequest do
  let(:valid_body) { { hostname: "login.shop.test" } }

  it_behaves_like "a required field", :hostname
  it_behaves_like "a hostname field", :hostname
end
