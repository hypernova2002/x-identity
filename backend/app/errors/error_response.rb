# Builds the standardized error body shared by controllers, the exceptions app and middleware.
class ErrorResponse
  attr_reader :code, :message, :details

  # @param errors [ActiveModel::Errors]
  # @return [Array<Hash{Symbol => String}>]
  def self.details_for(errors)
    errors.map { |error| { field: error.attribute.to_s, message: error.message } }
  end

  # @param code [Symbol] a key of {ErrorCodes::REGISTRY}
  # @param message [String, nil] overrides the registry's default message
  # @param details [Array<Hash{Symbol => String}>]
  # @raise [KeyError] if the code is not registered
  def initialize(code:, message: nil, details: [])
    @definition = ErrorCodes.fetch(code)
    @code = code.to_sym
    @message = message || @definition[:default_message]
    @details = details
  end

  # @return [Integer]
  def status
    @definition[:status]
  end

  # @return [Hash]
  def body
    { error: { code: code, message: message, details: details } }
  end
end
