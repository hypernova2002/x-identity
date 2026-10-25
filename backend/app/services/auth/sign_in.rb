module Auth
  # Email and password sign-in, for console users and end users alike.
  class SignIn
    # @param context [SignInContext]
    def initialize(context:)
      @context = context
      @realm = context.realm
      @configuration = context.configuration
    end

    # @param email [String]
    # @param password [String]
    # @return [SignInResult]
    # @raise [ApiError] `invalid_credentials`, `too_many_attempts` or `email_not_verified`
    def call(email:, password:)
      lockout = Lockout.new(owner: @realm.owner, configuration: @configuration)
      raise ApiError.new(:too_many_attempts) if lockout.locked?(email)

      user = @realm.users.find_by(email: email)

      unless Passwords::Hasher.new.matches?(password, user&.password_digest) && user.active?
        lockout.register_failure(email)
        @context.recorder.record(action: "#{@realm.event_prefix}.sign_in_failed", target: user, metadata: { email: email })
        raise ApiError.new(:invalid_credentials)
      end

      lockout.reset(email)
      raise ApiError.new(:email_not_verified) if @configuration.require_email_verification && !user.email_verified?
      # Only after a correct password, so it doesn't reveal who has a passkey.
      raise ApiError.new(:passkey_required) if passkey_instead?(user)

      SignInFlow.new(context: @context).continue(user: user, amr: [ Amr::PASSWORD ], authenticated_at: Time.current)
    end

    private

    # Users with a passkey that works here sign in with it, when the configuration says so, unless
    # they're recovering after a password reset.
    def passkey_instead?(user)
      return false unless @configuration.passwordless_after_passkey && @configuration.passkeys_enabled? && !user.recovering_passkey?

      relying_party = @context.passkey_relying_party(user)
      relying_party.present? && user.webauthn_credentials.exists?(rp_id: relying_party.id)
    end
  end
end
