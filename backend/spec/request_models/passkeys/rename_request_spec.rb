require "rails_helper"

RSpec.describe Passkeys::RenameRequest do
  let(:valid_body) { { name: "Work laptop" } }

  it_behaves_like "a required field", :name
  it_behaves_like "a string field", :name, min: 1, max: 60
end
