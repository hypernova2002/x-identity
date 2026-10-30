require "rails_helper"

RSpec.describe Auth::RefreshRequest do
  let(:valid_body) { { refresh_token: "refresh-token" } }

  it_behaves_like "a refresh token request"
end
