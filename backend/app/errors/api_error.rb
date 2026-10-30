# Base error for anything the API reports to clients. Rendered by {ApplicationController}.
class ApiError < StandardError
  attr_reader :code, :reason, :params, :details

  # @param field [String, Symbol]
  # @param detail_code [Symbol] a key of `errors.messages`, see {ErrorDetail}
  # @param params [Hash] values the detail's message refers to
  # @return [ApiError] a `validation_failed` error with one detail
  def self.validation(field, detail_code, **params)
    new(:validation_failed, details: [ ErrorDetail.build(field, detail_code, **params) ])
  end

  # @param record [ActiveModel::Validations]
  # @param field_names [Hash{Symbol => String}] renames model attributes to request field names
  # @return [ApiError] a `validation_failed` error built from the record's errors
  def self.from_record(record, field_names: {})
    details = record.errors.map { |error| ErrorDetail.from(error, field: field_names.fetch(error.attribute, error.attribute)) }
    new(:validation_failed, details: details)
  end

  # @param code [Symbol] a key of {ErrorCodes::REGISTRY}
  # @param reason [Symbol, nil] which case of the code this is, a key of `errors.reasons` in
  #   config/locales/en.yml; its message replaces the code's default
  # @param params [Hash] values the reason's message refers to, e.g. a group's name
  # @param details [Array<Hash>] field-level problems, see {ErrorDetail}
  # @raise [KeyError] if the code is not registered
  def initialize(code, reason: nil, params: {}, details: [])
    @code = code.to_sym
    @reason = reason&.to_sym
    @params = params
    @details = details
    super(ErrorResponse.message_for(@code, reason: @reason, params: params))
  end

  # @return [Integer]
  def status
    ErrorCodes.fetch(code)[:status]
  end
end
