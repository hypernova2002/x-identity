module IdentityProviders
  # Redeems the authorization code a provider sent to the callback for the provider's ID token.
  class CodeRedemption
    APPLE_AUDIENCE = "https://appleid.apple.com".freeze
    APPLE_SECRET_LIFETIME = 5.minutes

    # @param provider [IdentityProvider]
    # @param http_client [HttpClient]
    def initialize(provider:, http_client: HttpClient.new)
      @provider = provider
      @http_client = http_client
    end

    # @param code [String]
    # @param code_verifier [String, nil] sent when the provider supports PKCE
    # @return [String] the ID token
    # @raise [ApiError] `identity_provider_error`
    def call(code:, code_verifier: nil)
      form = { "grant_type" => "authorization_code", "code" => code, "redirect_uri" => @provider.callback_url }
      form["code_verifier"] = code_verifier if code_verifier

      response =
        if basic_auth?
          @http_client.post_form(token_endpoint, form, basic_auth: [ @provider.client_id, client_secret ])
        else
          @http_client.post_form(token_endpoint, form.merge("client_id" => @provider.client_id, "client_secret" => client_secret))
        end

      id_token = response["id_token"]
      raise ApiError.new(:identity_provider_error) unless id_token.is_a?(String) && id_token.present?

      id_token
    rescue HttpClient::Error => error
      Rails.logger.warn("Identity provider #{@provider.uid} code redemption failed: #{error.message}")
      raise ApiError.new(:identity_provider_error)
    end

    private

    def token_endpoint
      @provider.endpoints["token_endpoint"]
    end

    # OIDC defaults to client_secret_basic when the provider doesn't say; Google and Apple take the secret in the form.
    def basic_auth?
      return false unless @provider.kind_oidc?

      methods = @provider.metadata["token_endpoint_auth_methods_supported"]
      methods.blank? || methods.include?("client_secret_basic")
    end

    def client_secret
      @provider.kind_apple? ? apple_client_secret : @provider.client_secret
    end

    # Apple's client secret is a short-lived JWT signed with the team's key.
    def apple_client_secret
      now = Time.current.to_i
      claims = { iss: @provider.apple_team_id, iat: now, exp: now + APPLE_SECRET_LIFETIME.to_i, aud: APPLE_AUDIENCE, sub: @provider.client_id }
      JWT.encode(claims, @provider.apple_signing_key, "ES256", { kid: @provider.apple_key_id })
    end
  end
end
