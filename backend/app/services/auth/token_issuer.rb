module Auth
  # Issues a signed JWT access token and a rotating refresh token for an account's console user.
  class TokenIssuer
    AUDIENCE = "x-identity-console".freeze

    # @param account [Account]
    def initialize(account:)
      @account = account
      @configuration = account.auth_configuration!
    end

    # @param user [User]
    # @param authenticated_at [Time] when the user signed in; carried across refreshes as `auth_time`
    # @param amr [Array<String>] authentication methods used, e.g. `["pwd", "otp"]`
    # @param family_id [String] the refresh token family; a new sign-in starts a new family
    # @param refresh_expires_at [Time, nil] keeps a family's absolute lifetime fixed across rotations
    # @return [TokenSet]
    def issue(user:, authenticated_at:, amr:, family_id: SecureRandom.uuid, refresh_expires_at: nil)
      now = Time.current
      refresh_token = SecureRandom.base58(43)

      RefreshToken.create!(
        subject: user,
        token_digest: RefreshToken.digest(refresh_token),
        family_id: family_id,
        authenticated_at: authenticated_at,
        amr: amr,
        expires_at: refresh_expires_at || now + @configuration.refresh_token_ttl
      )

      TokenSet.new(
        access_token: access_token(user:, authenticated_at:, amr:, family_id:, now:),
        refresh_token: refresh_token,
        expires_in: @configuration.access_token_ttl.to_i
      )
    end

    private

    def access_token(user:, authenticated_at:, amr:, family_id:, now:)
      key = SigningKeys::Rotator.new(owner: @account, configuration: @configuration).current

      payload = {
        iss: @account.token_issuer,
        sub: user.uid,
        aud: AUDIENCE,
        iat: now.to_i,
        exp: (now + @configuration.access_token_ttl).to_i,
        auth_time: authenticated_at.to_i,
        amr: amr,
        sid: family_id,
        jti: SecureRandom.uuid
      }

      JWT.encode(payload, key.signing_key, key.algorithm, { kid: key.kid, typ: "at+jwt" })
    end
  end
end
