# Rails exceptions app: renders unhandled exceptions and routing errors in the standard error shape.
# Inherits from ActionController::API rather than ApplicationController so its rescue handlers can't loop.
class ErrorsController < ActionController::API
  def show
    status = request.path_info.delete_prefix("/").to_i
    error = ErrorResponse.new(code: ErrorCodes.for_status(status))
    render json: error.body, status: error.status
  end
end
