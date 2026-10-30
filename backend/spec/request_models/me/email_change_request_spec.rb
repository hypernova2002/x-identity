require "rails_helper"

RSpec.describe Me::EmailChangeRequest do
  let(:valid_body) { { new_email: "dana@acme.test", current_password: "a-good-password" } }

  it_behaves_like "a required field", :new_email
  it_behaves_like "an email field", :new_email

  it_behaves_like "a required field", :current_password
  it_behaves_like "a password field", :current_password

  it_behaves_like "an optional field", :otp_code
  it_behaves_like "an otp code field", :otp_code
end
