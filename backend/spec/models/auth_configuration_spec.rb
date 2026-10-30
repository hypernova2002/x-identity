require "rails_helper"

RSpec.describe AuthConfiguration do
  describe "#password_violations" do
    subject(:configuration) { described_class.new(password_min_length: 10) }

    it "accepts a password that meets the rules" do
      expect(configuration.password_violations("long enough pass")).to be_empty
    end

    it "enforces the minimum length" do
      expect(configuration.password_violations("short")).to eq(
        [ { field: "password", code: "too_short", message: "is too short (minimum is 10 characters)", params: { count: 10 } } ]
      )
    end

    it "enforces the platform maximum length" do
      expect(configuration.password_violations("a" * 129, field: :new_password).map { |detail| detail.slice(:field, :code, :params) }).to eq(
        [ { field: "new_password", code: "too_long", params: { count: 128 } } ]
      )
    end

    it "enforces each required character class" do
      configuration.assign_attributes(password_require_uppercase: true, password_require_number: true, password_require_symbol: true)

      expect(configuration.password_violations("lowercaseonly").pluck(:code)).to eq(%w[needs_uppercase needs_number needs_symbol])
    end
  end

  describe "validations" do
    let(:configuration) { build(:account).build_auth_configuration }

    it "limits access token lifetimes to the platform maximum" do
      configuration.access_token_ttl_seconds = AuthConfiguration::MAX_ACCESS_TOKEN_TTL_SECONDS + 1

      expect(configuration).not_to be_valid
    end

    it "only allows supported signing algorithms" do
      configuration.signing_algorithm = "HS256"

      expect(configuration).not_to be_valid
    end

    it "uses exactly one OTP method" do
      configuration.otp_method = "hotp"
      expect(configuration).to be_valid

      [ "both", "", nil ].each do |method|
        configuration.otp_method = method
        expect(configuration).not_to be_valid
      end
    end
  end
end
