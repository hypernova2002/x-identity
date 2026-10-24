module Auth
  # Exchanges a refresh token for a new token set. Each refresh token works once; presenting a
  # used one is treated as theft and revokes its whole family.
  class Refresh
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] must be the client the token was issued to
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil)
      @realm = realm
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
      @configuration = realm.auth_configuration
    end

    # @param refresh_token [String]
    # @return [TokenSet]
    # @raise [ApiError] `invalid_token`, `session_expired`, `mfa_required` or `app_access_denied`
    def call(refresh_token:)
      record = RefreshToken.find_by_token(refresh_token)
      user = record&.subject
      raise ApiError.new(:invalid_token) unless @realm.owns?(user) && record.app_client_id == @app_client&.id

      outcome = RefreshToken.transaction do
        record.lock!
        rejection = rejection_for(record, user)
        next rejection if rejection

        record.mark_used!
        TokenIssuer.new(realm: @realm, app_client: @app_client).issue(
          user: user,
          authenticated_at: record.authenticated_at,
          amr: record.amr,
          family_id: record.family_id,
          refresh_expires_at: record.expires_at,
          scope: record.scope,
          device_session: record.device_session
        )
      end

      raise ApiError.new(outcome) if outcome.is_a?(Symbol)

      record.device_session&.touch_activity!(**DeviceDetails.for(@app_client, ip: @ip, user_agent: @user_agent))

      outcome
    end

    private

    def rejection_for(record, user)
      if record.used?
        RefreshToken.revoke_family!(record.family_id)
        @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
          .record(action: "#{@realm.event_prefix}.refresh_token_reused", actor: user, target: user)
        return :invalid_token
      end

      return :invalid_token if record.revoked? || !user.active?
      return :app_access_denied if user.is_a?(EndUser) && @app_client && !Apps::Access.allowed?(@app_client, user)
      return :session_expired if record.expired?

      if idle?(record) || (@configuration.mfa_required? && !record.amr.include?("otp"))
        RefreshToken.revoke_family!(record.family_id)
        return idle?(record) ? :session_expired : :mfa_required
      end

      nil
    end

    def idle?(record)
      timeout = @configuration.session_idle_timeout
      timeout.present? && record.created_at < timeout.ago
    end
  end
end
