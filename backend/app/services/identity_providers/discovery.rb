module IdentityProviders
  # Loads an OpenID Connect provider's discovery document and keeps the parts sign-in needs.
  class Discovery
    WELL_KNOWN_PATH = "/.well-known/openid-configuration".freeze
    KEPT_KEYS = %w[
      issuer authorization_endpoint token_endpoint jwks_uri
      token_endpoint_auth_methods_supported code_challenge_methods_supported
    ].freeze

    # @param http_client [HttpClient]
    def initialize(http_client: HttpClient.new)
      @http_client = http_client
    end

    # @param discovery_url [String] the issuer, or its full `/.well-known/openid-configuration` URL
    # @return [Hash{String => Object}]
    # @raise [ApiError] `validation_failed` on `discovery_url`
    def fetch(discovery_url)
      url = discovery_url.to_s.end_with?(WELL_KNOWN_PATH) ? discovery_url : "#{discovery_url.to_s.chomp('/')}#{WELL_KNOWN_PATH}"
      document = @http_client.get_json(url)
      metadata = document.slice(*KEPT_KEYS)

      missing = IdentityProvider::METADATA_KEYS.reject { |key| metadata[key].is_a?(String) && metadata[key].start_with?("https://") }
      raise ApiError.validation(:discovery_url, :incomplete_discovery, missing: missing) if missing.any?
      raise ApiError.validation(:discovery_url, :discovery_issuer_mismatch) if url != "#{metadata['issuer'].chomp('/')}#{WELL_KNOWN_PATH}"

      metadata
    rescue HttpClient::Error => error
      raise ApiError.validation(:discovery_url, :not_loadable, reason: error.message)
    end
  end
end
