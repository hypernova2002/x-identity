require "rails_helper"

RSpec.describe EndUserMe::ConfirmEmailChangeRequest do
  let(:valid_body) { { code: "123456" } }

  it_behaves_like "a required field", :code
  it_behaves_like "an email code field", :code
end
