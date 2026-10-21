module Auth
  # Verifies an access token against one realm's keys, issuer and audiences. A token from another
  # account or project fails here even with a valid signature, because its `kid` and `iss` won't match.
  class AccessTokenVerifier
    REQUIRED_CLAIMS = %w[iss sub aud exp iat auth_time sid token_use].freeze

    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    def initialize(realm:)
      @realm = realm
    end

    # @param token [String]
    # @return [Hash] the verified claims
    # @raise [ApiError] `invalid_token` when the token can't be trusted
    def verify(token)
      _payload, header = JWT.decode(token, nil, false)
      key = @realm.owner.signing_keys.published.find_by(kid: header["kid"])
      raise ApiError.new(:invalid_token) if key.nil?

      claims, = JWT.decode(
        token,
        key.verification_key,
        true,
        algorithm: key.algorithm,
        iss: @realm.token_issuer,
        verify_iss: true,
        required_claims: REQUIRED_CLAIMS
      )
      raise ApiError.new(:invalid_token) unless claims["token_use"] == "access" && @realm.accepts_audience?(claims["aud"])

      claims
    rescue JWT::DecodeError
      raise ApiError.new(:invalid_token)
    end
  end
end
