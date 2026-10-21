module Auth
  class SignOut
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil)
      @realm = realm
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
    end

    # Revokes the refresh token's whole family. Unknown tokens are ignored so sign-out always succeeds.
    # @param refresh_token [String]
    def call(refresh_token:)
      record = RefreshToken.find_by_token(refresh_token)
      user = record&.subject
      return unless @realm.owns?(user) && record.app_client_id == @app_client&.id

      RefreshToken.revoke_family!(record.family_id)
      @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
        .record(action: "#{@realm.event_prefix}.signed_out", actor: user, target: user)
    end
  end
end
