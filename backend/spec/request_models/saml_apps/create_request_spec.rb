require "rails_helper"

RSpec.describe SamlApps::CreateRequest do
  let(:valid_body) { { name: "Shop", entity_id: "https://shop.test", acs_urls: [ "https://shop.test/acs" ] } }

  it_behaves_like "saml app fields", required: %i[name entity_id acs_urls]
end
