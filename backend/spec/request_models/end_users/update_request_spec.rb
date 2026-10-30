require "rails_helper"

RSpec.describe EndUsers::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name, nullable: true

  it_behaves_like "an optional field", :custom_attributes
  it_behaves_like "a custom attributes field", :custom_attributes

  it_behaves_like "an optional field", :status
  it_behaves_like "an enum field", :status, values: EndUser.statuses.keys
end
