require "rails_helper"

RSpec.describe Projects::CreateRequest do
  let(:valid_body) { { name: "Shop" } }

  it_behaves_like "a required field", :name
  it_behaves_like "a name field", :name
end
