require "rails_helper"

RSpec.describe AuthConfiguration do
  describe "#password_violations" do
    subject(:configuration) { described_class.new(password_min_length: 10) }

    it "accepts a password that meets the rules" do
      expect(configuration.password_violations("long enough pass")).to be_empty
    end

    it "enforces the minimum length" do
      expect(configuration.password_violations("short")).to eq([ "must be at least 10 characters" ])
    end

    it "enforces the platform maximum length" do
      expect(configuration.password_violations("a" * 129)).to eq([ "must be at most 128 characters" ])
    end

    it "enforces each required character class" do
      configuration.assign_attributes(password_require_uppercase: true, password_require_number: true, password_require_symbol: true)

      expect(configuration.password_violations("lowercaseonly")).to eq(
        [ "must include an uppercase letter", "must include a number", "must include a symbol" ]
      )
    end
  end

  describe "validations" do
    let(:configuration) { build(:account).build_auth_configuration }

    it "limits access token lifetimes to the platform maximum" do
      configuration.access_token_ttl_minutes = AuthConfiguration::MAX_ACCESS_TOKEN_TTL_MINUTES + 1

      expect(configuration).not_to be_valid
    end

    it "only allows supported signing algorithms" do
      configuration.signing_algorithm = "HS256"

      expect(configuration).not_to be_valid
    end
  end
end
