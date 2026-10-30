require "rails_helper"

RSpec.describe Me::ChangePasswordRequest do
  let(:valid_body) { { current_password: "the-old-password", new_password: "a-good-password" } }

  it_behaves_like "a required field", :current_password
  it_behaves_like "a password field", :current_password

  it_behaves_like "a required field", :new_password
  it_behaves_like "a password field", :new_password
end
