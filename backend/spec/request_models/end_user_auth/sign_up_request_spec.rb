require "rails_helper"

RSpec.describe EndUserAuth::SignUpRequest do
  let(:valid_body) { { client_id: "app_123", email: "dana@acme.test", password: "a-good-password" } }

  it_behaves_like "an end-user client request"

  it_behaves_like "a required field", :email
  it_behaves_like "an email field", :email

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name

  it_behaves_like "an optional field", :custom_attributes
  it_behaves_like "a custom attributes field", :custom_attributes
end
