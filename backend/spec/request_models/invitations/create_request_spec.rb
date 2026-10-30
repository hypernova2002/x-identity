require "rails_helper"

RSpec.describe Invitations::CreateRequest do
  let(:valid_body) { { email: "dana@acme.test", role: "member" } }

  it_behaves_like "a required field", :email
  it_behaves_like "an email field", :email

  it_behaves_like "a required field", :role
  it_behaves_like "an account role field", :role
end
