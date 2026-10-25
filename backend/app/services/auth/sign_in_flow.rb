module Auth
  # Decides what a user who has proven some factors must do next: answer another challenge,
  # or receive tokens. Shared by password sign-in and every challenge response. Sign-ins through
  # hosted login carry their interaction, end with a {SignInCompletion} instead of tokens, and their
  # challenges can only be answered through that interaction.
  class SignInFlow
    CHALLENGES = %w[otp passkey new_password mfa_setup].freeze

    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param interaction [OneTimeToken, nil] the hosted login interaction the sign-in belongs to
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil, interaction: nil)
      @realm = realm
      @app_client = app_client
      @interaction = interaction
      @ip = ip
      @user_agent = user_agent
      @configuration = realm.auth_configuration
    end

    # @param user [User, EndUser]
    # @param amr [Array<String>] factors proven so far
    # @param authenticated_at [Time]
    # @param recovery_codes [Array<String>, nil] passed through to the client after MFA setup
    # @return [SignInResult]
    def continue(user:, amr:, authenticated_at:, recovery_codes: nil)
      app = @interaction&.subject || @app_client
      Apps::Access.authorize!(app, user, recorder: recorder) if user.is_a?(EndUser) && app

      challenge, mfa_methods = next_challenge(user, amr)

      if challenge
        _record, session = OneTimeToken.issue!(
          subject: user,
          purpose: :sign_in_challenge,
          data: {
            "challenge" => challenge,
            "amr" => amr,
            "authenticated_at" => authenticated_at.utc.iso8601(6),
            "app_client_id" => @app_client&.id,
            "interaction_id" => @interaction&.id,
            "mfa_methods" => mfa_methods
          }.compact
        )
        return SignInResult.challenged(challenge, session, recovery_codes: recovery_codes, mfa_methods: mfa_methods)
      end

      user.record_sign_in!
      recorder.record(action: "#{@realm.event_prefix}.signed_in", actor: user, target: user, metadata: { amr: amr })
      if @interaction
        return SignInResult.completed(SignInCompletion.new(user: user, amr: amr, authenticated_at: authenticated_at), recovery_codes: recovery_codes)
      end

      device_session = DeviceSession.start!(subject: user, amr: amr, authenticated_at: authenticated_at, **DeviceDetails.for(@app_client, ip: @ip, user_agent: @user_agent))
      tokens = TokenIssuer.new(realm: @realm, app_client: @app_client).issue(user: user, authenticated_at: authenticated_at, amr: amr, device_session: device_session)
      SignInResult.authenticated(tokens, recovery_codes: recovery_codes)
    end

    private

    def recorder
      @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
    end

    # @return [Array(String, Array<String>), Array(String, nil), nil] the challenge, and for a second
    #   factor the methods that can answer it
    def next_challenge(user, amr)
      mfa = Factors.mfa?(amr)
      unless @configuration.mfa_off? || mfa
        passkey = usable_passkey?(user)
        return [ "otp", passkey ? %w[otp passkey] : %w[otp] ] if user.mfa_enabled?
        # Users with only a passkey need it as a second factor where MFA is required, and where it works.
        return [ "passkey", %w[passkey] ] if passkey && @configuration.mfa_required?
      end
      return [ "new_password", nil ] if amr.include?("pwd") && user.password_expired?(@configuration)
      return [ "mfa_setup", nil ] if @configuration.mfa_required? && !user.mfa_enabled? && !mfa

      nil
    end

    def usable_passkey?(user)
      relying_party = Passkeys::RelyingParties.for_sign_in(user, interaction: @interaction)
      relying_party.present? && user.webauthn_credentials.exists?(rp_id: relying_party.id)
    end
  end
end
