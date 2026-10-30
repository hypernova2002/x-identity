# Shared examples for request model fields, one example per validation. The including spec defines
# `valid_body`, a minimal body the request model accepts; each example changes one field of it.
module RequestFieldHelpers
  def body_with(field, value)
    valid_body.merge(field => value)
  end

  def expect_accepted(body)
    expect(described_class.error_details(body)).to eq([])
    expect { described_class.new(body) }.not_to raise_error
  end

  def expect_rejected(body, field, message = "is invalid")
    expect(described_class.error_details(body)).to eq([ { field: field.to_s, message: message } ])
    expect { described_class.new(body) }.to raise_error(Dry::Struct::Error)
  end
end

RSpec.configure do |config|
  config.include RequestFieldHelpers, type: :request_model
  config.define_derived_metadata(file_path: %r{/spec/request_models/}) { |metadata| metadata[:type] ||= :request_model }
end

RSpec.shared_examples "a required field" do |field|
  it "requires #{field}" do
    expect_rejected(valid_body.except(field), field, "is required")
  end
end

RSpec.shared_examples "an optional field" do |field|
  it "accepts a body without #{field}" do
    expect_accepted(valid_body.except(field))
  end
end

RSpec.shared_examples "a nullable field" do |field, nullable|
  if nullable
    it "accepts null for #{field}" do
      expect_accepted(body_with(field, nil))
      expect(described_class.new(body_with(field, nil)).to_h).to include(field => nil)
    end
  else
    it "rejects null for #{field}" do
      expect_rejected(body_with(field, nil), field)
    end
  end
end

RSpec.shared_examples "a field accepting" do |field, values|
  values.each do |value|
    it "accepts #{value.inspect.truncate(60)} for #{field}" do
      expect_accepted(body_with(field, value))
    end
  end
end

RSpec.shared_examples "a field rejecting" do |field, values|
  values.each do |value|
    it "rejects #{value.inspect.truncate(60)} for #{field}" do
      expect_rejected(body_with(field, value), field)
    end
  end
end

# `value` builds a valid string of a given length, for fields with a format.
RSpec.shared_examples "a string field" do |field, max:, min: 0, nullable: false, value: ->(length) { "a" * length }|
  it "accepts #{max} characters for #{field}" do
    expect_accepted(body_with(field, value.call(max)))
  end

  it "rejects #{max + 1} characters for #{field}" do
    expect_rejected(body_with(field, value.call(max + 1)), field)
  end

  if min.positive?
    it "accepts #{min} characters for #{field}" do
      expect_accepted(body_with(field, value.call(min)))
    end

    it "rejects #{min - 1} characters for #{field}" do
      expect_rejected(body_with(field, min == 1 ? "" : value.call(min - 1)), field)
    end
  end

  it_behaves_like "a field rejecting", field, [ 123, [ "a" ], { "a" => "b" } ]
  it_behaves_like "a nullable field", field, nullable
end

RSpec.shared_examples "an enum field" do |field, values:, nullable: false|
  it_behaves_like "a field accepting", field, values
  it_behaves_like "a field rejecting", field, [ "not-a-value", 1, *values.map(&:upcase).without(*values).first(1) ]
  it_behaves_like "a nullable field", field, nullable
end

RSpec.shared_examples "a boolean field" do |field, nullable: false|
  it_behaves_like "a field accepting", field, [ true, false ]
  it_behaves_like "a field rejecting", field, [ "true", 1 ]
  it_behaves_like "a nullable field", field, nullable
end

RSpec.shared_examples "an integer field" do |field, min:, max:, nullable: false|
  it_behaves_like "a field accepting", field, [ min, max ]
  it_behaves_like "a field rejecting", field, [ min - 1, max + 1, 1.5, min.to_s ]
  it_behaves_like "a nullable field", field, nullable
end

# `item` is a valid entry; `invalid_items` are entries the array must reject. `item_max` adds the
# length checks for arrays of strings.
RSpec.shared_examples "an array field" do |field, max:, item:, min: 0, invalid_items: [], item_max: nil, nullable: false|
  it "accepts #{max} items for #{field}" do
    expect_accepted(body_with(field, Array.new(max) { item }))
  end

  it "rejects #{max + 1} items for #{field}" do
    expect_rejected(body_with(field, Array.new(max + 1) { item }), field)
  end

  if min.positive?
    it "rejects #{min - 1} items for #{field}" do
      expect_rejected(body_with(field, Array.new(min - 1) { item }), field)
    end
  else
    it "accepts no items for #{field}" do
      expect_accepted(body_with(field, []))
    end
  end

  if item_max
    it "accepts an item of #{item_max} characters for #{field}" do
      expect_accepted(body_with(field, [ "a" * item_max ]))
    end

    it "rejects an item of #{item_max + 1} characters for #{field}" do
      expect_rejected(body_with(field, [ "a" * (item_max + 1) ]), field)
    end
  end

  invalid_items.each do |invalid|
    it "rejects #{invalid.inspect.truncate(60)} as an item of #{field}" do
      expect_rejected(body_with(field, [ invalid ]), field)
    end
  end

  it_behaves_like "a field rejecting", field, [ item, { "a" => item } ]
  it_behaves_like "a nullable field", field, nullable
end

RSpec.shared_examples "a hash field" do |field, nullable: false|
  it_behaves_like "a field accepting", field, [ {}, { "a" => "b" } ]
  it_behaves_like "a field rejecting", field, [ "a", [ "a" ] ]
  it_behaves_like "a nullable field", field, nullable
end

RSpec.shared_examples "an email field" do |field, nullable: false|
  it_behaves_like "a string field", field, min: 3, max: 254, nullable: nullable, value: ->(length) { length < 8 ? "a@#{'b' * (length - 2)}" : "#{'a' * (length - 7)}@ab.com" }
  it_behaves_like "a field rejecting", field, [ "dana", "dana@", "@acme.test", "dana@acme test" ]

  it "normalises #{field}" do
    expect(described_class.new(body_with(field, " Dana@ACME.test ")).public_send(field)).to eq("dana@acme.test")
  end
end
