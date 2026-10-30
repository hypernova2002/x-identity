require "rails_helper"

RSpec.describe EndUserAuth::ClientRequest do
  let(:valid_body) { { client_id: "app_123" } }

  it_behaves_like "an end-user client request"
end
