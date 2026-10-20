require "rails_helper"

RSpec.describe ErrorCodes do
  describe ".fetch" do
    it "returns the registered definition" do
      expect(described_class.fetch(:not_found)).to eq(status: 404, default_message: "The requested resource could not be found.")
    end

    it "raises for an unregistered code" do
      expect { described_class.fetch(:made_up) }.to raise_error(KeyError)
    end
  end

  describe ".for_status" do
    it "returns the generic code for a known status" do
      expect(described_class.for_status(429)).to eq(:rate_limited)
    end

    it "falls back to internal_error for an unknown status" do
      expect(described_class.for_status(418)).to eq(:internal_error)
    end
  end

  describe "GENERIC_BY_STATUS" do
    it "only references registered codes whose status matches" do
      mismatched = described_class::GENERIC_BY_STATUS.reject { |status, code| described_class.fetch(code)[:status] == status }

      expect(mismatched).to be_empty
    end
  end
end
