require "rails_helper"

RSpec.describe Groups::CreateRequest do
  let(:valid_body) { { name: "Staff" } }

  it_behaves_like "group fields", required: %i[name]
end
