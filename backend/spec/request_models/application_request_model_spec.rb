require "rails_helper"

RSpec.describe ApplicationRequestModel do
  let(:request_class) do
    Class.new(described_class) do
      attribute :email, JsonModel::Types::String.constrained(max_size: 20)
      attribute :role, JsonModel::Types::String.enum("admin", "member").meta(description: "The member's role.")
      attribute? :age, JsonModel::Types::Integer.optional

      def self.name
        "ExampleRequest"
      end
    end
  end

  it "builds from a body with string keys" do
    expect(request_class.new("email" => "dana@acme.test", "role" => "admin").to_h).to eq(email: "dana@acme.test", role: "admin")
  end

  it "keeps an explicit null for optional fields" do
    expect(request_class.new(email: "dana@acme.test", role: "admin", age: nil).to_h).to include(age: nil)
  end

  it "rejects input that isn't an object" do
    expect { request_class.new("dana@acme.test") }.to raise_error(Dry::Struct::Error)
  end

  it "rejects unknown keys" do
    expect { request_class.new(email: "dana@acme.test", role: "admin", admin: true) }.to raise_error(Dry::Struct::Error)
  end

  describe ".error_details" do
    it "reports every missing, invalid and unknown field at once" do
      details = request_class.error_details("role" => "superuser", "age" => "old", "nickname" => "D")

      expect(details.map { |detail| detail.slice(:field, :code, :params) }).to eq(
        [
          { field: "email", code: "required", params: {} },
          { field: "role", code: "inclusion", params: { values: %w[admin member] } },
          { field: "age", code: "wrong_type", params: { type: "integer" } },
          { field: "nickname", code: "not_allowed", params: {} }
        ]
      )
    end

    it "names the limit a value broke, with an English message" do
      expect(request_class.error_details(email: "x" * 21, role: "admin")).to eq(
        [ { field: "email", code: "too_long", message: "is too long (maximum is 20 characters)", params: { count: 20 } } ]
      )
    end

    it "reports a broken rule of a list's item as invalid" do
      list_class = Class.new(described_class) do
        attribute :tags, JsonModel::Types::Array.of(JsonModel::Types::String.constrained(max_size: 3)).constrained(max_size: 2)

        def self.name
          "ExampleListRequest"
        end
      end

      expect(list_class.error_details(tags: %w[a b c]).sole).to include(code: "too_many", params: { count: 2 })
      expect(list_class.error_details(tags: %w[long]).sole).to include(code: "invalid", params: {})
    end
  end

  describe ".as_schema" do
    it "only lists keys that must be sent as required" do
      expect(request_class.as_schema[:required]).to eq(%i[email role])
    end

    it "includes each field's description" do
      expect(request_class.as_schema[:properties]).to include(role: include(description: "The member's role."))
      expect(request_class.as_schema[:properties][:email]).not_to have_key(:description)
    end

    it "documents that unknown keys are rejected" do
      expect(request_class.as_schema[:additionalProperties]).to be(false)
    end
  end
end
