class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(:validation_failed, details: ErrorResponse.details_for(error.record.errors))
  end

  rescue_from ActiveRecord::RecordNotUnique do
    render_error(:conflict)
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(:validation_failed, details: [ { field: error.param.to_s, message: "is required" } ])
  end

  rescue_from ApiError do |error|
    render_error(error.code, message: error.message, details: error.details)
  end

  private

  # Builds a request model from the request body, reporting every invalid, missing or unknown field.
  # @param request_model_class [Class<ApplicationRequestModel>]
  # @return [ApplicationRequestModel]
  # @raise [ApiError] `validation_failed`
  def parse_request(request_model_class)
    input = request.request_parameters
    request_model_class.new(input)
  rescue Dry::Struct::Error
    details = request_model_class.error_details(input).presence || [ { field: "body", message: "is invalid" } ]
    raise ApiError.new(:validation_failed, details: details)
  end

  # Who is calling, for the audit log. Passed to services as plain keyword arguments.
  # @return [Hash{Symbol => String, nil}]
  def client_info
    { ip: request.remote_ip, user_agent: request.user_agent }
  end

  def render_error(code, message: nil, details: [])
    error = ErrorResponse.new(code: code, message: message, details: details)
    render json: error.body, status: error.status
  end
end
