require "rails_helper"

RSpec.describe Auth::ChallengeResponseRequest do
  let(:valid_body) { { challenge: "otp", session: "challenge-session" } }

  it_behaves_like "a challenge response request"
end
