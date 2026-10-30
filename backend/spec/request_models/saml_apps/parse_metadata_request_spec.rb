require "rails_helper"

RSpec.describe SamlApps::ParseMetadataRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :metadata_xml
  it_behaves_like "a string field", :metadata_xml, min: 1, max: 256_000

  it_behaves_like "an optional field", :metadata_url
  it_behaves_like "a url field", :metadata_url
end
