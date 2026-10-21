module Oidc
  # Authenticates an app client at the token and revocation endpoints: client_secret_basic,
  # client_secret_post, or just the client id for public clients.
  class ClientAuthentication
    # @param project [Project]
    def initialize(project:)
      @project = project
    end

    # @param authorization [String, nil] the Authorization header
    # @param params [Hash{String => String}]
    # @return [AppClient]
    # @raise [Error] `invalid_client` or `invalid_request`
    def authenticate(authorization:, params:)
      client_id, secret = credentials(authorization, params)
      app_client = @project.app_clients.enabled.find_by(uid: client_id.to_s)
      raise Error.new("invalid_client", "The app client is unknown, disabled, or its secret is wrong.") unless client_id.present? && app_client&.authenticate(secret)

      app_client
    end

    private

    def credentials(authorization, params)
      return [ params["client_id"], params["client_secret"] ] unless authorization.to_s.start_with?("Basic ")
      raise Error.new("invalid_request", "Send the client secret in one place only.") if params["client_secret"].present?

      decoded = Base64.strict_decode64(authorization.to_s.delete_prefix("Basic "))
      decoded.split(":", 2).map { |part| CGI.unescape(part) }
    rescue ArgumentError
      raise Error.new("invalid_client", "The Authorization header isn't valid Basic credentials.")
    end
  end
end
