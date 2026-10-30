require "rails_helper"

RSpec.describe EndUsers::CreateRequest do
  let(:valid_body) { { email: "dana@acme.test" } }

  it_behaves_like "a required field", :email
  it_behaves_like "an email field", :email

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name, nullable: true

  it_behaves_like "an optional field", :custom_attributes
  it_behaves_like "a hash field", :custom_attributes

  it_behaves_like "an optional field", :send_invitation
  it_behaves_like "a boolean field", :send_invitation
end
