require "rails_helper"

RSpec.describe Projects::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name

  it_behaves_like "an optional field", :allow_self_sign_up
  it_behaves_like "a boolean field", :allow_self_sign_up

  it_behaves_like "an optional field", :confirm_sign_up_url
  it_behaves_like "a url field", :confirm_sign_up_url, nullable: true

  it_behaves_like "an optional field", :reset_password_url
  it_behaves_like "a url field", :reset_password_url, nullable: true

  it_behaves_like "an optional field", :accept_invitation_url
  it_behaves_like "a url field", :accept_invitation_url, nullable: true
end
