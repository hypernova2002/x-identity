module Auth
  # Where one sign-in happens: the realm it signs into, the app or hosted login interaction it goes
  # through, and the caller, for the audit log. Each step of the sign-in shares it, so they agree on
  # where passkeys work.
  class SignInContext
    attr_reader :realm, :app_client, :interaction, :ip, :user_agent

    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] required for end users
    # @param interaction [OneTimeToken, nil] set for sign-ins through hosted login
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(realm:, app_client: nil, interaction: nil, ip: nil, user_agent: nil)
      @realm = realm
      @app_client = app_client
      @interaction = interaction
      @ip = ip
      @user_agent = user_agent
      @relying_parties = {}
    end

    # @return [AuthConfiguration]
    def configuration
      @configuration ||= realm.auth_configuration
    end

    # @return [AuditEvents::Recorder]
    def recorder
      realm.recorder(ip: ip, user_agent: user_agent, app_client: app_client)
    end

    # @return [Hash{Symbol => String, nil}] for services that record the caller
    def client_info
      { ip: ip, user_agent: user_agent }
    end

    # @param user [User, EndUser]
    # @return [WebAuthn::RelyingParty, nil] where the user could use a passkey in this sign-in
    def passkey_relying_party(user)
      key = [ user.class.name, user.id ]
      return @relying_parties[key] if @relying_parties.key?(key)

      @relying_parties[key] = Passkeys::RelyingParties.for_sign_in(user, interaction: interaction, app_client: app_client)
    end
  end
end
