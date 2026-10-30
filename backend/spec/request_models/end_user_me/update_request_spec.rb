require "rails_helper"

RSpec.describe EndUserMe::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name, nullable: true

  it_behaves_like "an optional field", :custom_attributes
  it_behaves_like "a hash field", :custom_attributes
end
