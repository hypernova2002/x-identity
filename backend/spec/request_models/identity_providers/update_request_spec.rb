require "rails_helper"

RSpec.describe IdentityProviders::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "identity provider fields"

  it_behaves_like "an optional field", :client_secret
  it_behaves_like "a string field", :client_secret, max: 1000
  it_behaves_like "a field accepting", :client_secret, [ "" ]

  it_behaves_like "an optional field", :apple_private_key
  it_behaves_like "a string field", :apple_private_key, max: 4000
  it_behaves_like "a field accepting", :apple_private_key, [ "" ]

  it_behaves_like "an optional field", :on_custom_domain
  it_behaves_like "a boolean field", :on_custom_domain
end
