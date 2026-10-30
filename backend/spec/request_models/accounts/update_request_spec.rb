require "rails_helper"

RSpec.describe Accounts::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name
end
