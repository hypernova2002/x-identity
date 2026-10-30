require "rails_helper"

RSpec.describe EndUserAuth::ChallengeResponseRequest do
  let(:valid_body) { { client_id: "app_123", challenge: "otp", session: "challenge-session" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a challenge response request"
end
