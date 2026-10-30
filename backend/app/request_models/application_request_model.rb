# Base class for request body models. Subclasses declare their fields with JsonModel types; the same
# declaration validates incoming bodies and produces the OpenAPI request schema (`as_schema`).
# Unknown keys are rejected. Domain rules (uniqueness, password policy) stay in models and services.
class ApplicationRequestModel < Dry::Struct
  include JsonModel::Schema

  transform_keys(&:to_sym)
  schema schema.strict

  # Field-level problems with a request body, all at once rather than only the first one.
  # @param input [Hash]
  # @return [Array<Hash{Symbol => String}>]
  def self.error_details(input)
    input = input.to_h.deep_symbolize_keys
    known = schema.keys.map(&:name)

    unknown = (input.keys - known).map { |key| { field: key.to_s, message: "is not allowed" } }
    declared = schema.keys.filter_map do |key|
      if !input.key?(key.name)
        { field: key.name.to_s, message: "is required" } if key.required?
      elsif key.try(input[key.name]).failure?
        { field: key.name.to_s, message: "is invalid" }
      end
    end

    declared + unknown
  end

  # json_model_rb 0.1.30 marks `attribute?` keys as required unless their type is also `.optional`,
  # so `required` is rebuilt from the struct's own key definitions. It also drops the descriptions
  # given with `.meta(description:)`, so they're added back to each property.
  # @return [Hash] JSON Schema for the request body
  def self.as_schema
    required = schema.keys.select(&:required?).map(&:name).sort
    schema_hash = super.except(:required).merge(required.any? ? { required: required } : {}).merge(additionalProperties: false)
    return schema_hash unless schema_hash[:properties]

    schema_hash.merge(properties: schema_hash[:properties].to_h { |name, property| [name, describe(name, property)] })
  end

  def self.describe(name, property)
    description = schema.keys.find { |key| key.name == name.to_sym }&.type&.meta&.dig(:description)
    description ? property.merge(description: description) : property
  end
  private_class_method :describe
end
