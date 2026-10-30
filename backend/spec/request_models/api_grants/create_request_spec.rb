require "rails_helper"

RSpec.describe ApiGrants::CreateRequest do
  let(:valid_body) { { api_uid: "api_123", scopes: [ "orders:read" ] } }

  it_behaves_like "a required field", :api_uid
  it_behaves_like "a uid field", :api_uid

  it_behaves_like "api grant scopes"
end
