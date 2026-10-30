require "rails_helper"

RSpec.describe Groups::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "group fields"
end
