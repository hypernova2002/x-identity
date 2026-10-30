require "rails_helper"

RSpec.describe AppClients::CreateRequest do
  let(:valid_body) { { name: "Shop", client_type: "public" } }

  it_behaves_like "app client fields", required: %i[name]

  it_behaves_like "a required field", :client_type
  it_behaves_like "an enum field", :client_type, values: AppClient.client_types.values

  it_behaves_like "an optional field", :machine
  it_behaves_like "a boolean field", :machine
end
