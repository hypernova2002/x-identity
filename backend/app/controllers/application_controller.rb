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
    render_error(:validation_failed, details: [ ErrorDetail.build(error.param, :required) ])
  end

  rescue_from ApiError do |error|
    render_error(error.code, reason: error.reason, params: error.params, details: error.details)
  end

  private

  # Builds a request model from the request body, reporting every invalid, missing or unknown field.
  # @param request_model_class [Class<ApplicationRequestModel>]
  # @param input [Hash] the body by default; pass `request.query_parameters` for GET requests
  # @return [ApplicationRequestModel]
  # @raise [ApiError] `validation_failed`
  def parse_request(request_model_class, input = request.request_parameters)
    request_model_class.new(input)
  rescue Dry::Struct::Error
    details = request_model_class.error_details(input).presence || [ ErrorDetail.build(:body, :invalid) ]
    raise ApiError.new(:validation_failed, details: details)
  end

  # Lets browsers, CDNs and HTTP clients reuse a response that's the same for everyone (keys,
  # discovery documents) for `max_age`, then keep serving it briefly while they refetch.
  # @param max_age [ActiveSupport::Duration]
  def cache_publicly(max_age)
    expires_in max_age, public: true, stale_while_revalidate: 1.minute
  end

  # @return [ProjectDomain, nil] the verified custom domain the request arrived on
  def custom_domain
    CustomDomainConstraint.domain(request)
  end

  # Who is calling, for the audit log. Passed to services as plain keyword arguments.
  # @return [Hash{Symbol => String, nil}]
  def client_info
    { ip: request.remote_ip, user_agent: request.user_agent }
  end

  def render_error(code, reason: nil, params: {}, details: [])
    error = ErrorResponse.new(code: code, reason: reason, params: params, details: details)
    render json: error.body, status: error.status
  end
end
