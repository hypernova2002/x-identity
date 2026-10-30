require "rails_helper"

RSpec.describe Passkeys::ChallengeOptionsRequest do
  let(:valid_body) { { session: "challenge-session" } }

  it_behaves_like "a challenge session request"
end
