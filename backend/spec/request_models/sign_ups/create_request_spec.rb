require "rails_helper"

RSpec.describe SignUps::CreateRequest do
  let(:valid_body) { { account_name: "Acme", slug: "acme", name: "Dana", email: "dana@acme.test", password: "a-good-password" } }

  it_behaves_like "a required field", :account_name
  it_behaves_like "a name field", :account_name

  it_behaves_like "a required field", :slug
  it_behaves_like "a string field", :slug, min: 3, max: 40
  it_behaves_like "a field accepting", :slug, %w[Acme acme-2]
  it_behaves_like "a field rejecting", :slug, [ "acme corp", "acme_corp", "acmé" ]

  it_behaves_like "a required field", :name
  it_behaves_like "a name field", :name

  it_behaves_like "a required field", :email
  it_behaves_like "an email field", :email

  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password
end
