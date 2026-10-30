require "rails_helper"

RSpec.describe Auth::ConfirmEmailRequest do
  let(:valid_body) { { token: "confirm-token" } }

  it_behaves_like "a required field", :token
  it_behaves_like "a token field", :token
end
