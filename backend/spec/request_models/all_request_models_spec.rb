require "rails_helper"

Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/request_models"))

# A nested model given a description with `.meta` is a copy of that model, not another one.
request_models = ApplicationRequestModel.descendants.select do |request_model|
  request_model.name.present? && request_model.meta.empty? &&
    Object.const_source_location(request_model.name)&.first.to_s.start_with?(Rails.root.join("app/request_models").to_s)
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
      when "object"
        if variant[:properties]
          variant[:properties].each { |name, nested| schema_problems(nested, "#{path}.#{name}", problems) }
        else
          problems << "#{path} has no maximum number of keys" unless variant[:maxProperties]
          schema_problems(variant[:additionalProperties], "#{path}{}", problems) if variant[:additionalProperties].is_a?(Hash)
        end
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

      it "limits the size of every string, array and object" do
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
