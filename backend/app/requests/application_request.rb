# Base class for typed request bodies. Subclasses declare their fields with JsonModel types; the
# same declaration validates incoming params and produces the OpenAPI request schema (`as_schema`).
# Domain rules (lengths, uniqueness, password policy) stay in models and services.
class ApplicationRequest < Dry::Struct
  include JsonModel::Schema

  transform_keys(&:to_sym)

  # Builds the request from controller params, reporting every missing or mistyped field at once.
  # Keys the request doesn't declare are dropped.
  # @param params [ActionController::Parameters, Hash]
  # @return [ApplicationRequest]
  # @raise [ApiError] `validation_failed`
  def self.from_params(params)
    input = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).deep_symbolize_keys
    input = input.slice(*schema.keys.map(&:name))

    details = schema.keys.filter_map do |key|
      if !input.key?(key.name)
        { field: key.name.to_s, message: "is required" } if key.required?
      elsif key.try(input[key.name]).failure?
        { field: key.name.to_s, message: "is invalid" }
      end
    end
    raise ApiError.new(:validation_failed, details: details) if details.any?

    new(input)
  end

  # json_model_rb 0.1.30 marks `attribute?` keys as required unless their type is also `.optional`,
  # so `required` is rebuilt from the struct's own key definitions.
  # @return [Hash] JSON Schema for the request body
  def self.as_schema
    required = schema.keys.select(&:required?).map(&:name).sort
    super.except(:required).merge(required.any? ? { required: required } : {})
  end
end
