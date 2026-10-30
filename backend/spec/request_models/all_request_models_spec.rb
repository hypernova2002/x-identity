require "rails_helper"

Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/request_models"))

request_models = ApplicationRequestModel.descendants.select do |request_model|
  request_model.name.present? && Object.const_source_location(request_model.name)&.first.to_s.start_with?(Rails.root.join("app/request_models").to_s)
end

RSpec.describe "Every request model" do
  def schema_problems(property, path, problems = [])
    variants = property[:anyOf] || [ property ]
    variants.each do |variant|
      case variant[:type]
      when "string"
        problems << "#{path} has no maximum length" unless variant[:maxLength] || variant[:enum]
      when "array"
        problems << "#{path} has no maximum number of items" unless variant[:maxItems]
        schema_problems(variant[:items], "#{path}[]", problems) if variant[:items]
      end
    end
    problems
  end

  request_models.sort_by(&:name).each do |request_model|
    describe request_model.name do
      let(:properties) { request_model.as_schema[:properties] || {} }

      it "describes every field" do
        expect(properties.reject { |_name, property| property[:description] }.keys).to eq([])
      end

      it "limits the size of every string and array" do
        expect(properties.flat_map { |name, property| schema_problems(property, name.to_s) }).to eq([])
      end

      it "rejects unknown fields" do
        expect(request_model.error_details(unexpected_field: "x")).to include(field: "unexpected_field", message: "is not allowed")
      end

      it "has its own spec" do
        expect(Rails.root.join("spec/request_models/#{request_model.name.underscore}_spec.rb")).to exist
      end
    end
  end
end
