require "rails_helper"

RSpec.describe Me::DisableOtpRequest do
  let(:valid_body) { { current_password: "a-good-password", code: "123456" } }

  it_behaves_like "a required field", :current_password
  it_behaves_like "a password field", :current_password

  it_behaves_like "a required field", :code
  it_behaves_like "an otp code field", :code
end
