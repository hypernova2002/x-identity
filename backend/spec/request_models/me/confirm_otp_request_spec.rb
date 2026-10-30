require "rails_helper"

RSpec.describe Me::ConfirmOtpRequest do
  let(:valid_body) { { code: "123456" } }

  it_behaves_like "a required field", :code
  it_behaves_like "an otp code field", :code
end
