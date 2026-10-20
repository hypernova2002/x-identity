# Base error for anything the API reports to clients. Rendered by {ApplicationController}.
class ApiError < StandardError
  attr_reader :code, :details

  # @param errors [Hash{String, Symbol => String, Array<String>}] messages by field
  # @return [ApiError] a `validation_failed` error with one detail per message
  def self.validation(errors)
    details = errors.flat_map { |field, messages| Array(messages).map { |message| { field: field.to_s, message: message } } }
    new(:validation_failed, details: details)
  end

  # @param record [ActiveModel::Validations]
  # @param field_names [Hash{Symbol => String}] renames model attributes to request field names
  # @return [ApiError] a `validation_failed` error built from the record's errors
  def self.from_record(record, field_names: {})
    details = record.errors.map { |error| { field: field_names.fetch(error.attribute, error.attribute).to_s, message: error.message } }
    new(:validation_failed, details: details)
  end

  # @param code [Symbol] a key of {ErrorCodes::REGISTRY}
  # @param message [String, nil] overrides the registry's default message
  # @param details [Array<Hash{Symbol => String}>] field-level problems as `{ field:, message: }`
  # @raise [KeyError] if the code is not registered
  def initialize(code, message: nil, details: [])
    @code = code.to_sym
    @details = details
    super(message || ErrorCodes.fetch(@code)[:default_message])
  end

  # @return [Integer]
  def status
    ErrorCodes.fetch(code)[:status]
  end
end
