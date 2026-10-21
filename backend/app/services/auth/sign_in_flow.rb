module Auth
  # Decides what a user who has proven some factors must do next: answer another challenge,
  # or receive tokens. Shared by password sign-in and every challenge response. Sign-ins through
  # hosted login carry their interaction, end with a {SignInCompletion} instead of tokens, and their
  # challenges can only be answered through that interaction.
  class SignInFlow
    CHALLENGES = %w[otp new_password mfa_setup].freeze

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
      challenge = next_challenge(user, amr)

      if challenge
        _record, session = OneTimeToken.issue!(
          subject: user,
          purpose: :sign_in_challenge,
          data: {
            "challenge" => challenge,
            "amr" => amr,
            "authenticated_at" => authenticated_at.utc.iso8601(6),
            "app_client_id" => @app_client&.id,
            "interaction_id" => @interaction&.id
          }
        )
        return SignInResult.challenged(challenge, session, recovery_codes: recovery_codes)
      end

      user.record_sign_in!
      @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
        .record(action: "#{@realm.event_prefix}.signed_in", actor: user, target: user, metadata: { amr: amr })
      if @interaction
        return SignInResult.completed(SignInCompletion.new(user: user, amr: amr, authenticated_at: authenticated_at), recovery_codes: recovery_codes)
      end

      tokens = TokenIssuer.new(realm: @realm, app_client: @app_client).issue(user: user, authenticated_at: authenticated_at, amr: amr)
      SignInResult.authenticated(tokens, recovery_codes: recovery_codes)
    end

    private

    def next_challenge(user, amr)
      return "otp" if !@configuration.mfa_off? && user.mfa_enabled? && !amr.include?("otp")
      return "new_password" if amr.include?("pwd") && user.password_expired?(@configuration)
      return "mfa_setup" if @configuration.mfa_required? && !user.mfa_enabled?

      nil
    end
  end
end
