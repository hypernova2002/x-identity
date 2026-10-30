require "rails_helper"

RSpec.describe Me::StartOtpRequest do
  let(:valid_body) { {} }

  it "accepts an empty body" do
    expect_accepted({})
  end
end
