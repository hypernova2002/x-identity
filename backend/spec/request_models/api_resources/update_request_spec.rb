require "rails_helper"

RSpec.describe ApiResources::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "api resource fields"
end
