# Builds the standardized error body shared by controllers, the exceptions app and middleware.
class ErrorResponse
  attr_reader :code, :reason, :params, :message, :details

  # @param errors [ActiveModel::Errors]
  # @return [Array<Hash>]
  def self.details_for(errors)
    errors.map { |error| ErrorDetail.from(error) }
  end

  # @param code [Symbol] a key of {ErrorCodes::REGISTRY}
  # @param reason [Symbol, nil] a key of `errors.reasons`
  # @param params [Hash]
  # @return [String] the reason's message, or the code's default
  def self.message_for(code, reason: nil, params: {})
    return ErrorCodes.fetch(code)[:default_message] unless reason

    I18n.t(reason, scope: "errors.reasons", **params.transform_values { |value| value.is_a?(Array) ? value.join(", ") : value }, raise: true)
  end

  # @param code [Symbol] a key of {ErrorCodes::REGISTRY}
  # @param reason [Symbol, nil] a key of `errors.reasons`
  # @param params [Hash] values the reason's message refers to
  # @param details [Array<Hash>] see {ErrorDetail}
  # @raise [KeyError] if the code is not registered
  def initialize(code:, reason: nil, params: {}, details: [])
    @definition = ErrorCodes.fetch(code)
    @code = code.to_sym
    @reason = reason
    @params = params
    @message = self.class.message_for(@code, reason: reason, params: params)
    @details = details
  end

  # @return [Integer]
  def status
    @definition[:status]
  end

  # @return [Hash]
  def body
    { error: { code: code, reason: reason, message: message, params: params, details: details } }
  end
end
