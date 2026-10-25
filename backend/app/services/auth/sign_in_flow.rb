module Auth
  # Decides what a user who has proven some factors must do next: answer another challenge,
  # or receive tokens. Shared by password sign-in and every challenge response. Sign-ins through
  # hosted login carry their interaction, end with a {SignInCompletion} instead of tokens, and their
  # challenges can only be answered through that interaction.
  class SignInFlow
    # @param context [SignInContext]
    def initialize(context:)
      @context = context
    end

    # @param user [User, EndUser]
    # @param amr [Array<String>] factors proven so far
    # @param authenticated_at [Time]
    # @param recovery_codes [Array<String>, nil] passed through to the client after MFA setup
    # @return [SignInResult]
    def continue(user:, amr:, authenticated_at:, recovery_codes: nil)
      app = @context.interaction&.subject || @context.app_client
      Apps::Access.authorize!(app, user, recorder: @context.recorder) if user.is_a?(EndUser) && app

      challenge = ChallengePolicy.new(configuration: @context.configuration, relying_party: @context.passkey_relying_party(user)).next_for(user, amr)

      if challenge
        _record, session = OneTimeToken.issue!(
          subject: user,
          purpose: :sign_in_challenge,
          data: {
            "challenge" => challenge.name,
            "amr" => amr,
            "authenticated_at" => authenticated_at.utc.iso8601(6),
            "app_client_id" => @context.app_client&.id,
            "interaction_id" => @context.interaction&.id,
            "mfa_methods" => challenge.mfa_methods.presence
          }.compact
        )
        return SignInResult.challenged(challenge, session, recovery_codes: recovery_codes)
      end

      user.record_sign_in!
      @context.recorder.record(action: "#{@context.realm.event_prefix}.signed_in", actor: user, target: user, metadata: { amr: amr })
      if @context.interaction
        return SignInResult.completed(SignInCompletion.new(user: user, amr: amr, authenticated_at: authenticated_at), recovery_codes: recovery_codes)
      end

      device_session = DeviceSession.start!(
        subject: user, amr: amr, authenticated_at: authenticated_at, **DeviceDetails.for(@context.app_client, **@context.client_info)
      )
      tokens = TokenIssuer.new(realm: @context.realm, app_client: @context.app_client).issue(user: user, authenticated_at: authenticated_at, amr: amr, device_session: device_session)
      SignInResult.authenticated(tokens, recovery_codes: recovery_codes)
    end
  end
end
