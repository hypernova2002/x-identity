# Single source of truth for every error code the API can return.
module ErrorCodes
  REGISTRY = {
    bad_request: { status: 400, default_message: "The request could not be understood." },
    unauthorized: { status: 401, default_message: "Authentication is required." },
    invalid_credentials: { status: 401, default_message: "The email or password is incorrect." },
    invalid_token: { status: 401, default_message: "The token is invalid or has expired." },
    session_expired: { status: 401, default_message: "Your session has expired. Sign in again." },
    mfa_required: { status: 401, default_message: "Multi-factor authentication is required. Sign in again to continue." },
    invalid_challenge: { status: 401, default_message: "The sign-in session is invalid or has expired. Start signing in again." },
    invalid_otp: { status: 401, default_message: "The verification code is incorrect." },
    forbidden: { status: 403, default_message: "You do not have permission to perform this action." },
    email_not_verified: { status: 403, default_message: "Verify your email address before signing in." },
    mfa_required_by_policy: { status: 403, default_message: "Multi-factor authentication is required by your account's policy and can't be turned off." },
    not_found: { status: 404, default_message: "The requested resource could not be found." },
    method_not_allowed: { status: 405, default_message: "The request method is not supported for this resource." },
    not_acceptable: { status: 406, default_message: "The requested response format is not supported." },
    conflict: { status: 409, default_message: "The request conflicts with the current state of the resource." },
    email_taken: { status: 409, default_message: "A user with this email address already exists in this account." },
    mfa_already_enabled: { status: 409, default_message: "Multi-factor authentication is already turned on." },
    last_owner: { status: 409, default_message: "An account must keep at least one active owner." },
    validation_failed: { status: 422, default_message: "One or more fields are invalid." },
    too_many_attempts: { status: 429, default_message: "Too many failed attempts. Try again later." },
    rate_limited: { status: 429, default_message: "Too many requests. Try again later." },
    internal_error: { status: 500, default_message: "An unexpected error occurred." }
  }.freeze

  GENERIC_BY_STATUS = {
    400 => :bad_request,
    401 => :unauthorized,
    403 => :forbidden,
    404 => :not_found,
    405 => :method_not_allowed,
    406 => :not_acceptable,
    409 => :conflict,
    422 => :validation_failed,
    429 => :rate_limited
  }.freeze

  # @param code [Symbol] a key of {REGISTRY}
  # @return [Hash{Symbol => Object}] the code's `status` and `default_message`
  # @raise [KeyError] if the code is not registered
  def self.fetch(code)
    REGISTRY.fetch(code.to_sym)
  end

  # @param status [Integer] an HTTP status code
  # @return [Symbol] the generic code for the status, or `:internal_error` when none is registered
  def self.for_status(status)
    GENERIC_BY_STATUS.fetch(status, :internal_error)
  end
end
