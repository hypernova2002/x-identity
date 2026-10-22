module Oidc
  # The token endpoint: redeems authorization codes (checking the redirect URI and PKCE) and
  # refresh tokens. Refresh tokens are only issued when the app asked for offline_access.
  class TokenExchange
    VERIFIER_FORMAT = /\A[A-Za-z0-9\-._~]{43,128}\z/

    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param app_client [AppClient] already authenticated
    # @param params [Hash{String => String}]
    # @return [Hash] the token response
    # @raise [Error]
    def call(app_client:, params:)
      case params["grant_type"]
      when "authorization_code" then redeem_code(app_client, params)
      when "refresh_token" then refresh(app_client, params)
      else raise Error.new("unsupported_grant_type", "Use the authorization_code or refresh_token grant.")
      end
    end

    private

    def redeem_code(app_client, params)
      verifier = params["code_verifier"].to_s
      raise Error.new("invalid_request", "code_verifier is required.") unless verifier.match?(VERIFIER_FORMAT)

      record = OneTimeToken.find_usable(params["code"].to_s, purpose: :oidc_code)
      data = record&.data || {}
      valid = record && data["app_client_id"] == app_client.id && data["redirect_uri"] == params["redirect_uri"] &&
        ActiveSupport::SecurityUtils.secure_compare(data["code_challenge"].to_s, s256(verifier))
      raise Error.new("invalid_grant", "The code is invalid, expired or already used, or doesn't match this request.") unless valid && record.consume!

      end_user = record.subject
      raise Error.new("invalid_grant", "The user can no longer sign in.") unless end_user.active?

      tokens = Auth::TokenIssuer.new(realm: @project.realm, app_client: app_client).issue(
        user: end_user, authenticated_at: Time.iso8601(data["authenticated_at"]), amr: data["amr"],
        nonce: data["nonce"], refresh: data["scope"].to_s.split(" ").include?("offline_access"), scope: data["scope"]
      )
      response_for(tokens, scope: data["scope"])
    end

    def refresh(app_client, params)
      tokens = Auth::Refresh.new(realm: @project.realm, app_client: app_client, ip: @ip, user_agent: @user_agent)
        .call(refresh_token: params["refresh_token"].to_s)
      response_for(tokens)
    rescue ApiError
      raise Error.new("invalid_grant", "The refresh token is invalid, expired or revoked.")
    end

    def response_for(tokens, scope: nil)
      {
        access_token: tokens.access_token, token_type: "Bearer", expires_in: tokens.expires_in,
        id_token: tokens.id_token, refresh_token: tokens.refresh_token, scope: scope
      }.compact
    end

    def s256(verifier)
      Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    end
  end
end
