class ApplicationController < ActionController::API
  before_action :set_request_context

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

  def set_request_context
    Current.request_context = RequestContext.new(ip: request.remote_ip, user_agent: request.user_agent)
  end

  def request_context
    Current.request_context
  end

  def render_error(code, message: nil, details: [])
    error = ErrorResponse.new(code: code, message: message, details: details)
    render json: error.body, status: error.status
  end
end
