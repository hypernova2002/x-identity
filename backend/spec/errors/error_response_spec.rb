require "rails_helper"

RSpec.describe ErrorResponse do
  describe "#body" do
    it "renders the standard error shape" do
      response = described_class.new(code: :validation_failed, details: [ { field: "email", message: "is invalid" } ])

      expect(response.body).to eq(
        error: {
          code: :validation_failed,
          message: "One or more fields are invalid.",
          details: [ { field: "email", message: "is invalid" } ]
        }
      )
    end
  end

  describe ".details_for" do
    let(:model_class) do
      Class.new do
        include ActiveModel::Model

        attr_accessor :email

        validates :email, presence: true

        def self.name
          "ErrorResponseSpecModel"
        end
      end
    end

    it "maps model errors to field details" do
      record = model_class.new.tap(&:validate)

      expect(described_class.details_for(record.errors)).to eq([ { field: "email", message: "can't be blank" } ])
    end
  end
end
