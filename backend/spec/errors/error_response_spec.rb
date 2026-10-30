require "rails_helper"

RSpec.describe ErrorResponse do
  describe "#body" do
    it "renders the standard error shape" do
      response = described_class.new(code: :validation_failed, details: [ ErrorDetail.build(:email, :invalid) ])

      expect(response.body).to eq(
        error: {
          code: :validation_failed,
          reason: nil,
          message: "One or more fields are invalid.",
          params: {},
          details: [ { field: "email", code: "invalid", message: "is invalid", params: {} } ]
        }
      )
    end
  end

  describe ".details_for" do
    let(:model_class) do
      Class.new do
        include ActiveModel::Model

        attr_accessor :email, :slug

        validates :email, presence: true
        validates :slug, length: { maximum: 3 }, format: { with: /\A[a-z]*\z/, message: :invalid_slug }

        def self.name
          "ErrorResponseSpecModel"
        end
      end
    end

    it "maps model errors to field details, with their codes and params" do
      record = model_class.new(slug: "ACME").tap(&:validate)

      expect(described_class.details_for(record.errors)).to eq(
        [
          { field: "email", code: "blank", message: "can't be blank", params: {} },
          { field: "slug", code: "too_long", message: "is too long (maximum is 3 characters)", params: { count: 3 } },
          { field: "slug", code: "invalid_slug", message: "may only contain lowercase letters, numbers and hyphens", params: {} }
        ]
      )
    end
  end
end
