require "rails_helper"

RSpec.describe ApiError do
  it "uses the registry's default message" do
    expect(described_class.new(:forbidden).message).to eq("You do not have permission to perform this action.")
  end

  it "uses its reason's message, with the reason's params" do
    error = described_class.new(:conflict, reason: :already_group_member, params: { email: "dana@acme.test", group: "Support" })

    expect([ error.reason, error.message ]).to eq([ :already_group_member, "dana@acme.test is already in Support." ])
  end

  it "refuses reasons without a message" do
    expect { described_class.new(:conflict, reason: :made_up) }.to raise_error(I18n::MissingTranslationData)
  end

  it "builds a validation error with one detail" do
    expect(described_class.validation(:sort, :unknown_sort, values: %w[name email]).details).to eq(
      [ { field: "sort", code: "unknown_sort", message: "must be one of: name, email", params: { values: %w[name email] } } ]
    )
  end

  it "takes its status from the registry" do
    expect(described_class.new(:validation_failed).status).to eq(422)
  end

  it "refuses unregistered codes" do
    expect { described_class.new(:made_up) }.to raise_error(KeyError)
  end
end
