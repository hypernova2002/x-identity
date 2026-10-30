require "rails_helper"

RSpec.describe Auth::ConfirmEmailChangeRequest do
  let(:valid_body) { { token: "change-token" } }

  it_behaves_like "a required field", :token
  it_behaves_like "a token field", :token
end
