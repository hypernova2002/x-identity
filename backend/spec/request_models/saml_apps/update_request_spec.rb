require "rails_helper"

RSpec.describe SamlApps::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "saml app fields"

  it_behaves_like "an optional field", :on_custom_domain
  it_behaves_like "a boolean field", :on_custom_domain
end
