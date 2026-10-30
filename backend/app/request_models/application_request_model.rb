# Base class for request body models. Subclasses declare their fields with JsonModel types; the same
# declaration validates incoming bodies and produces the OpenAPI request schema (`as_schema`).
# Unknown keys are rejected. Domain rules (uniqueness, password policy) stay in models and services.
class ApplicationRequestModel < Dry::Struct
  include JsonModel::Schema

  transform_keys(&:to_sym)
  schema schema.strict

  # json_model_rb 0.1.30 calls `transform_keys` on the input, so a nested model given a string or
  # array (e.g. `"scopes": ["orders:read"]`) would raise NoMethodError instead of failing validation.
  def self.new(attributes = default_attributes, safe = false, &block)
    raise Dry::Struct::Error, "#{name} must be an object" unless attributes.is_a?(Hash)

    super
  end

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

    schema_hash.merge(properties: schema_hash[:properties].to_h { |name, property| [ name, describe(name, property) ] })
  end

  def self.describe(name, property)
    key = schema.keys.find { |schema_key| schema_key.name == name.to_sym }
    description = key && description_of(key.type)
    description ? property.merge(description: description) : property
  end

  # A shared type's description also describes it when it's made `.optional` or given a constructor.
  def self.description_of(type)
    return unless type.respond_to?(:meta)

    type.meta[:description] ||
      (description_of(type.right) if type.is_a?(Dry::Types::Sum)) ||
      (description_of(type.type) if type.is_a?(Dry::Types::Constructor))
  end
  private_class_method :describe, :description_of
end
