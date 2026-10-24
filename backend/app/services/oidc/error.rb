module Oidc
  # An OAuth 2.0 / OpenID Connect error, reported in the protocol's own format rather than the API's.
  # Authorization errors with a known client and redirect URI go back to the client; the rest are
  # shown on the hosted login error page or returned as JSON.
  class Error < StandardError
    STATUSES = { "invalid_client" => 401, "slow_down" => 429 }.freeze

    attr_reader :code, :redirect_uri, :state, :retry_after

    # @param code [String] e.g. `invalid_request`, `invalid_grant`, `login_required`
    # @param description [String]
    # @param redirect_uri [String, nil] where to send the error, once the client and URI are verified
    # @param state [String, nil] the client's state, returned with redirected errors
    # @param retry_after [Integer, nil] seconds until a rate-limited client may try again
    def initialize(code, description, redirect_uri: nil, state: nil, retry_after: nil)
      @code = code
      @retry_after = retry_after
      @redirect_uri = redirect_uri
      @state = state
      super(description)
    end

    # @return [Integer]
    def status
      STATUSES.fetch(code, 400)
    end

    # @return [Hash{Symbol => String}]
    def body
      { error: code, error_description: message }
    end
  end
end
