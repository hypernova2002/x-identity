require "rails_helper"

RSpec.describe EndUserAuth::PasskeyChallengeOptionsRequest do
  let(:valid_body) { { client_id: "app_123", session: "challenge-session" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a challenge session request"
end
