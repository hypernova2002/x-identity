module Auth
  # Email and password sign-in for an account's console users.
  class SignIn
    # @param account [Account]
    def initialize(account:)
      @account = account
      @configuration = account.auth_configuration!
    end

    # @param email [String]
    # @param password [String]
    # @return [SignInResult]
    # @raise [ApiError] `invalid_credentials`, `too_many_attempts` or `email_not_verified`
    def call(email:, password:)
      email = email.to_s.strip.downcase
      lockout = Lockout.new(owner: @account, configuration: @configuration)
      raise ApiError.new(:too_many_attempts) if lockout.locked?(email)

      user = @account.users.find_by(email: email)

      unless Passwords::Hasher.new.matches?(password, user&.password_digest) && user.active?
        lockout.register_failure(email)
        AuditEvents::Recorder.new(account: @account).record(action: "user.sign_in_failed", target: user, metadata: { email: email })
        raise ApiError.new(:invalid_credentials)
      end

      lockout.reset(email)
      raise ApiError.new(:email_not_verified) if @configuration.require_email_verification && !user.email_verified?

      SignInFlow.new(account: @account).continue(user: user, amr: [ "pwd" ], authenticated_at: Time.current)
    end
  end
end
