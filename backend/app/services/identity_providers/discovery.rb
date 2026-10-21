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

      problems = IdentityProvider::METADATA_KEYS.filter_map do |key|
        value = metadata[key]
        "#{key} is missing" unless value.is_a?(String) && value.start_with?("https://")
      end
      problems << "issuer doesn't match the discovery URL" if problems.empty? && url != "#{metadata['issuer'].chomp('/')}#{WELL_KNOWN_PATH}"
      raise ApiError.validation(discovery_url: "isn't a usable OpenID Connect configuration: #{problems.join(', ')}") if problems.any?

      metadata
    rescue HttpClient::Error => error
      raise ApiError.validation(discovery_url: "couldn't be loaded: #{error.message}")
    end
  end
end
