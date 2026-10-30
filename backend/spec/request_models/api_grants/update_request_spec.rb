require "rails_helper"

RSpec.describe ApiGrants::UpdateRequest do
  let(:valid_body) { { scopes: [ "orders:read" ] } }

  it_behaves_like "api grant scopes"
end
