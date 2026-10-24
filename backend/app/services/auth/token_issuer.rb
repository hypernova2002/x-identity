module Auth
  # Issues a signed JWT access token and a rotating refresh token, plus an ID token for end users.
  class TokenIssuer
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] required for end users; becomes the token audience
    def initialize(realm:, app_client: nil)
      @realm = realm
      @app_client = app_client
      @configuration = realm.auth_configuration
    end

    # @param user [User, EndUser]
    # @param authenticated_at [Time] when the user signed in; carried across refreshes as `auth_time`
    # @param amr [Array<String>] authentication methods used, e.g. `["pwd", "otp"]`
    # @param family_id [String] the refresh token family; a new sign-in starts a new family
    # @param refresh_expires_at [Time, nil] keeps a family's absolute lifetime fixed across rotations
    # @param nonce [String, nil] echoed in the ID token, for OpenID Connect clients
    # @param refresh [Boolean] false issues no refresh token (OpenID Connect without offline_access)
    # @param scope [String, nil] OpenID Connect scopes; `groups` adds the user's groups to the ID token
    # @param device_session [DeviceSession, nil] the signed-in device; becomes the access token's `sid`
    # @return [TokenSet]
    def issue(user:, authenticated_at:, amr:, family_id: SecureRandom.uuid, refresh_expires_at: nil, nonce: nil, refresh: true, scope: nil,
      device_session: nil)
      now = Time.current
      refresh_token = SecureRandom.base58(43) if refresh

      if refresh
        RefreshToken.create!(
          subject: user,
          app_client_id: @app_client&.id,
          device_session_id: device_session&.id,
          token_digest: RefreshToken.digest(refresh_token),
          family_id: family_id,
          authenticated_at: authenticated_at,
          amr: amr,
          scope: scope,
          expires_at: refresh_expires_at || now + @configuration.refresh_token_ttl
        )
      end

      key = SigningKeys::Rotator.new(owner: @realm.owner, configuration: @configuration).current
      base = base_claims(user, authenticated_at, now)

      TokenSet.new(
        access_token: sign(key, base.merge(token_use: "access", amr: amr, sid: device_session&.uid || family_id, jti: SecureRandom.uuid, scope: scope).compact.merge(client_claims)),
        refresh_token: refresh_token,
        expires_in: @configuration.access_token_ttl.to_i,
        id_token: @app_client ? sign(key, base.merge(id_claims(user, scope)).merge({ nonce: nonce }.compact)) : nil
      )
    end

    private

    def base_claims(user, authenticated_at, now)
      {
        iss: @realm.token_issuer,
        sub: user.uid,
        aud: @realm.audience_for(@app_client),
        iat: now.to_i,
        exp: (now + @configuration.access_token_ttl).to_i,
        auth_time: authenticated_at.to_i
      }
    end

    def client_claims
      @app_client ? { client_id: @app_client.uid } : {}
    end

    def id_claims(user, scope)
      attributes = user.project.end_user_attribute_definitions.where(include_in_token: true).pluck(:key)
      {
        token_use: "id",
        email: user.email,
        email_verified: user.email_verified?,
        name: user.name,
        custom_attributes: user.custom_attributes.slice(*attributes),
        groups: (user.groups.order(:name).pluck(:name) if scope.to_s.split(" ").include?("groups"))
      }.compact
    end

    def sign(key, payload)
      JWT.encode(payload, key.signing_key, key.algorithm, { kid: key.kid, typ: "JWT" })
    end
  end
end
