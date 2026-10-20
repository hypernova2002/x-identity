require "rails_helper"

RSpec.describe CorsOriginPolicy do
  subject(:policy) { described_class.new(configured_origins: [ "https://console.example.com" ]) }

  it "allows a configured origin" do
    expect(policy.allowed?("https://console.example.com")).to be(true)
  end

  it "rejects an origin that is not configured" do
    expect(policy.allowed?("https://evil.example.com")).to be(false)
  end

  it "rejects requests without an origin" do
    expect(policy.allowed?(nil)).to be(false)
  end
end
