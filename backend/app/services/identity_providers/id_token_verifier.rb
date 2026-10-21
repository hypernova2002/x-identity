module IdentityProviders
  # Verifies an ID token from a provider: its signature against the provider's keys, issuer,
  # audience, expiry and nonce.
  class IdTokenVerifier
    ALGORITHMS = %w[RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512].freeze
    LEEWAY_SECONDS = 60

    # @param provider [IdentityProvider]
    # @param key_set [KeySet]
    def initialize(provider:, key_set: KeySet.new)
      @provider = provider
      @key_set = key_set
    end

    # Apple's native SDKs send the SHA-256 of the app's nonce to Apple, so the token's nonce may be
    # either the nonce itself or its hex digest.
    # @param id_token [String]
    # @param nonce [String]
    # @return [Hash{String => Object}] the verified claims
    # @raise [ApiError] `invalid_id_token` or `identity_provider_error`
    def verify(id_token, nonce:)
      claims, = JWT.decode(
        id_token, nil, true,
        algorithms: ALGORITHMS,
        jwks: @key_set.loader(@provider.endpoints["jwks_uri"]),
        iss: @provider.issuers,
        verify_iss: true,
        aud: @provider.audiences,
        verify_aud: true,
        required_claims: %w[sub exp iat],
        leeway: LEEWAY_SECONDS
      )
      raise ApiError.new(:invalid_id_token) unless nonce_matches?(claims["nonce"], nonce)

      claims
    rescue JWT::DecodeError
      raise ApiError.new(:invalid_id_token)
    rescue HttpClient::Error
      raise ApiError.new(:identity_provider_error)
    end

    private

    def nonce_matches?(claimed, nonce)
      return false unless claimed.is_a?(String) && nonce.present?

      [ nonce, OpenSSL::Digest::SHA256.hexdigest(nonce) ].any? { |candidate| ActiveSupport::SecurityUtils.secure_compare(claimed, candidate) }
    end
  end
end
