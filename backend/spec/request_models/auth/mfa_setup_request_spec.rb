require "rails_helper"

RSpec.describe Auth::MfaSetupRequest do
  let(:valid_body) { { session: "challenge-session" } }

  it_behaves_like "a challenge session request"
end
