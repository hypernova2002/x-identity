module Auth
  # Email and password sign-in, for console users and end users alike.
  class SignIn
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] required for end users
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil)
      @realm = realm
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
      @configuration = realm.auth_configuration
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
        recorder.record(action: "#{@realm.event_prefix}.sign_in_failed", target: user, metadata: { email: email })
        raise ApiError.new(:invalid_credentials)
      end

      lockout.reset(email)
      raise ApiError.new(:email_not_verified) if @configuration.require_email_verification && !user.email_verified?

      SignInFlow.new(realm: @realm, app_client: @app_client, ip: @ip, user_agent: @user_agent)
        .continue(user: user, amr: [ "pwd" ], authenticated_at: Time.current)
    end

    private

    def recorder
      @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
    end
  end
end
