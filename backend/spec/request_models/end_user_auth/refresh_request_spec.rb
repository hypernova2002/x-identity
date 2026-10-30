require "rails_helper"

RSpec.describe EndUserAuth::RefreshRequest do
  let(:valid_body) { { client_id: "app_123", refresh_token: "refresh-token" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a refresh token request"
end
