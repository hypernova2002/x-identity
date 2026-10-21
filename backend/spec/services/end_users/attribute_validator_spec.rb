require "rails_helper"

RSpec.describe EndUsers::AttributeValidator do
  let(:project) { create(:project) }
  let(:validator) { described_class.new(project: project) }

  before do
    create(:end_user_attribute_definition, project: project, key: "nickname", data_type: "string", max_length: 5)
    create(:end_user_attribute_definition, project: project, key: "age", data_type: "number")
    create(:end_user_attribute_definition, project: project, key: "newsletter", data_type: "boolean", required: true)
    create(:end_user_attribute_definition, project: project, key: "birthday", data_type: "date")
    create(:end_user_attribute_definition, project: project, key: "tier", data_type: "string", user_editable: false, required: true)
  end

  it "accepts valid values" do
    result = validator.validate({ nickname: "Cas", age: 30, newsletter: false, birthday: "1990-02-03" })

    expect([ result.values, result.details ]).to eq([ { "nickname" => "Cas", "age" => 30, "newsletter" => false, "birthday" => "1990-02-03" }, [] ])
  end

  it "rejects values of the wrong type" do
    result = validator.validate({ age: "thirty", newsletter: "yes", birthday: "03/02/1990" })

    expect(result.details.pluck(:field)).to eq(%w[custom_attributes.age custom_attributes.newsletter custom_attributes.birthday])
  end

  it "enforces the maximum string length" do
    expect(validator.validate({ nickname: "Casey Jones", newsletter: true }).details.pluck(:field)).to eq([ "custom_attributes.nickname" ])
  end

  it "rejects unknown attributes" do
    expect(validator.validate({ shoe_size: 42, newsletter: true }).details).to include({ field: "custom_attributes.shoe_size", message: "is not a known attribute" })
  end

  it "only requires attributes the caller can set" do
    expect(validator.validate({}).details).to eq([ { field: "custom_attributes.newsletter", message: "is required" } ])
  end

  it "requires every required attribute from admins" do
    expect(validator.validate({}, by_admin: true).details.pluck(:field)).to contain_exactly("custom_attributes.newsletter", "custom_attributes.tier")
  end

  it "keeps existing values on partial updates and clears nulls" do
    result = validator.validate({ nickname: nil }, existing: { "nickname" => "Cas", "newsletter" => true })

    expect(result.values).to eq("newsletter" => true)
  end
end
