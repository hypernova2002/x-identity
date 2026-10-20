module Auth
  # Decides what a user who has proven some factors must do next: answer another challenge,
  # or receive tokens. Shared by password sign-in and every challenge response.
  class SignInFlow
    CHALLENGES = %w[totp new_password mfa_setup].freeze

    # @param account [Account]
    def initialize(account:)
      @account = account
      @configuration = account.auth_configuration!
    end

    # @param user [User]
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
          data: { "challenge" => challenge, "amr" => amr, "authenticated_at" => authenticated_at.utc.iso8601(6) }
        )
        return SignInResult.challenged(challenge, session, recovery_codes: recovery_codes)
      end

      user.record_sign_in!
      AuditEvents::Recorder.new(account: @account).record(action: "user.signed_in", actor: user, target: user, metadata: { amr: amr })
      tokens = TokenIssuer.new(account: @account).issue(user: user, authenticated_at: authenticated_at, amr: amr)
      SignInResult.authenticated(tokens, recovery_codes: recovery_codes)
    end

    private

    def next_challenge(user, amr)
      return "totp" if !@configuration.mfa_off? && user.mfa_enabled? && !amr.include?("otp")
      return "new_password" if user.password_expired?(@configuration)
      return "mfa_setup" if @configuration.mfa_required? && !user.mfa_enabled?

      nil
    end
  end
end
