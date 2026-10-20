module Auth
  # Verifies an access token against the keys and issuer of one account. A token issued by another
  # account fails here even if its signature is valid, because its `kid` and `iss` won't match.
  class AccessTokenVerifier
    REQUIRED_CLAIMS = %w[iss sub aud exp iat auth_time sid].freeze

    # @param account [Account]
    def initialize(account:)
      @account = account
    end

    # @param token [String]
    # @return [Hash] the verified claims
    # @raise [ApiError] `invalid_token` when the token can't be trusted
    def verify(token)
      _payload, header = JWT.decode(token, nil, false)
      key = @account.signing_keys.published.find_by(kid: header["kid"])
      raise ApiError.new(:invalid_token) if key.nil?

      claims, = JWT.decode(
        token,
        key.verification_key,
        true,
        algorithm: key.algorithm,
        iss: @account.token_issuer,
        verify_iss: true,
        aud: TokenIssuer::AUDIENCE,
        verify_aud: true,
        required_claims: REQUIRED_CLAIMS
      )
      claims
    rescue JWT::DecodeError
      raise ApiError.new(:invalid_token)
    end
  end
end
