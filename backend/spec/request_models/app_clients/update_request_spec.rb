require "rails_helper"

RSpec.describe AppClients::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "app client fields"

  it_behaves_like "an optional field", :enabled
  it_behaves_like "a boolean field", :enabled

  it_behaves_like "an optional field", :token_requests_per_minute
  it_behaves_like "a token requests per minute field", :token_requests_per_minute, nullable: true
end
