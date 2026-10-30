require "rails_helper"

RSpec.describe HostedLogin::DiscoverRequest do
  let(:valid_body) { { email: "dana@acme.test" } }

  it_behaves_like "an email lookup request"
end
