require "rails_helper"

RSpec.describe SamlApps::AttributeMapping do
  let(:valid_body) { { name: "email", source: "email" } }

  it_behaves_like "a required field", :name
  it_behaves_like "a string field", :name, min: 1, max: 255

  it_behaves_like "a required field", :source
  it_behaves_like "a string field", :source, min: 1, max: 50
end
