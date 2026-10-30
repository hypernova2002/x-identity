require "rails_helper"

RSpec.describe IdentityProviders::CreateRequest do
  let(:valid_body) { { kind: "oidc", name: "Okta" } }

  it_behaves_like "a required field", :kind
  it_behaves_like "an enum field", :kind, values: IdentityProvider.kinds.values

  it_behaves_like "identity provider fields", required: %i[name]

  it_behaves_like "an optional field", :client_secret
  it_behaves_like "a string field", :client_secret, min: 1, max: 1000

  it_behaves_like "an optional field", :apple_private_key
  it_behaves_like "a string field", :apple_private_key, min: 1, max: 4000
end
