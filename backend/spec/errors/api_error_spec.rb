require "rails_helper"

RSpec.describe ApiError do
  it "uses the registry's default message" do
    expect(described_class.new(:forbidden).message).to eq("You do not have permission to perform this action.")
  end

  it "uses a custom message when given" do
    expect(described_class.new(:forbidden, message: "Only owners can do that.").message).to eq("Only owners can do that.")
  end

  it "takes its status from the registry" do
    expect(described_class.new(:validation_failed).status).to eq(422)
  end

  it "refuses unregistered codes" do
    expect { described_class.new(:made_up) }.to raise_error(KeyError)
  end
end
