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

  TYPE_NAMES = { String => "string", Integer => "integer", Float => "number", TrueClass => "boolean", FalseClass => "boolean", Array => "array", Hash => "object" }.freeze

  # Field-level problems with a request body, all at once rather than only the first one. Each
  # names the rule the value broke, e.g. `too_long` with its `count`; see {ErrorDetail}.
  # @param input [Hash]
  # @return [Array<Hash>]
  def self.error_details(input)
    input = input.to_h.symbolize_keys
    known = schema.keys.map(&:name)

    unknown = (input.keys - known).map { |key| ErrorDetail.build(key, :not_allowed) }
    declared = schema.keys.filter_map do |key|
      if !input.key?(key.name)
        ErrorDetail.build(key.name, :required) if key.required?
      elsif (result = key.try(input[key.name])).failure?
        code, params = broken_rule(result, input[key.name])
        ErrorDetail.build(key.name, code, **params)
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
  # @return [Array(Symbol, Hash)] the detail code and its params for the rule the value broke. Rules
  #   broken by an item of a list, a nested model or a custom attribute are reported as `invalid`.
  def self.broken_rule(result, value)
    error = result.error
    predicate, args = failed_predicate(error.result.to_ast) if error.is_a?(Dry::Types::ConstraintError) && error.result.respond_to?(:to_ast)
    return [ :invalid, {} ] unless predicate && args.to_h[:input] == value

    limit = args.first&.last
    case predicate
    when :type? then TYPE_NAMES.key?(limit) ? [ :wrong_type, { type: TYPE_NAMES[limit] } ] : [ :invalid, {} ]
    when :min_size? then [ value.is_a?(String) ? :too_short : :too_few, { count: limit } ]
    when :max_size? then [ value.is_a?(String) ? :too_long : :too_many, { count: limit } ]
    when :included_in? then [ :inclusion, { values: limit } ]
    when :gteq? then [ :greater_than_or_equal_to, { count: limit } ]
    when :lteq? then [ :less_than_or_equal_to, { count: limit } ]
    else [ :invalid, {} ]
    end
  end

  # The first rule that failed: hints are rules that weren't checked because an earlier one failed.
  def self.failed_predicate(ast)
    kind, body = ast
    case kind
    when :predicate then body
    when :and, :or then body.lazy.reject { |node| node.first == :hint }.filter_map { |node| failed_predicate(node) }.first
    end
  end
  private_class_method :describe, :description_of, :broken_rule, :failed_predicate
end
