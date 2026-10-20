require "rails_helper"

RSpec.describe ApplicationRequest do
  let(:request_class) do
    Class.new(described_class) do
      attribute :email, JsonModel::Types::String
      attribute :role, JsonModel::Types::String.enum("admin", "member")
      attribute? :age, JsonModel::Types::Integer.optional

      def self.name
        "ExampleRequest"
      end
    end
  end

  describe ".from_params" do
    it "builds the request from controller params" do
      params = ActionController::Parameters.new(email: "dana@acme.test", role: "admin")

      expect(request_class.from_params(params).to_h).to eq(email: "dana@acme.test", role: "admin")
    end

    it "drops keys the request doesn't declare" do
      request = request_class.from_params({ "email" => "dana@acme.test", "role" => "admin", "account_uid" => "acct_1" })

      expect(request.to_h.keys).to eq(%i[email role])
    end

    it "keeps an explicit null for optional fields" do
      expect(request_class.from_params({ email: "dana@acme.test", role: "admin", age: nil }).to_h).to include(age: nil)
    end

    it "reports every missing and mistyped field at once" do
      expect { request_class.from_params({ role: "superuser", age: "old" }) }.to raise_error(ApiError) { |error|
        expect([ error.code, error.details ]).to eq(
          [
            :validation_failed,
            [
              { field: "email", message: "is required" },
              { field: "role", message: "is invalid" },
              { field: "age", message: "is invalid" }
            ]
          ]
        )
      }
    end

    it "rejects values of the wrong JSON type" do
      expect { request_class.from_params({ email: 42, role: "admin" }) }.to raise_error(ApiError) { |error|
        expect(error.details).to eq([ { field: "email", message: "is invalid" } ])
      }
    end
  end

  describe ".as_schema" do
    it "only lists keys that must be sent as required" do
      expect(request_class.as_schema[:required]).to eq(%i[email role])
    end
  end
end
