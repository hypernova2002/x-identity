module Auth
  # Answers a sign-in challenge issued by {SignInFlow}. A session token stays valid across wrong
  # answers (failures count towards lockout) and is consumed only once the challenge is passed.
  class ChallengeResponse
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] must be the client the sign-in started with
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil)
      @realm = realm
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
      @configuration = realm.auth_configuration
    end

    # @param session [String]
    # @param challenge [String] one of {SignInFlow::CHALLENGES}
    # @param code [String, nil] for `otp` and `mfa_setup`
    # @param new_password [String, nil] for `new_password`
    # @return [SignInResult]
    def call(session:, challenge:, code: nil, new_password: nil)
      record = find_session!(session, challenge)
      user = record.subject
      amr = record.data["amr"]
      recovery_codes = nil

      case challenge
      when "otp"
        verify_otp!(user, code)
        amr |= [ "otp" ]
      when "new_password"
        Users::PasswordChange.new(user: user, ip: @ip, user_agent: @user_agent).set_password!(new_password)
      when "mfa_setup"
        recovery_codes = Mfa::OtpEnrollment.new(user: user, ip: @ip, user_agent: @user_agent).confirm(code: code)
        amr |= [ "otp" ]
      end

      raise ApiError.new(:invalid_challenge) unless record.consume!

      SignInFlow.new(realm: @realm, app_client: @app_client, ip: @ip, user_agent: @user_agent).continue(
        user: user,
        amr: amr,
        authenticated_at: Time.iso8601(record.data["authenticated_at"]),
        recovery_codes: recovery_codes
      )
    end

    # Starts OTP enrolment for a user answering the `mfa_setup` challenge.
    # @param session [String]
    # @param otp_type [String, nil] "totp" or "hotp"
    # @return [Mfa::Enrollment]
    def start_mfa_setup(session:, otp_type: nil)
      record = find_session!(session, "mfa_setup")
      Mfa::OtpEnrollment.new(user: record.subject, ip: @ip, user_agent: @user_agent).start(otp_type: otp_type)
    end

    private

    def find_session!(session, challenge)
      record = OneTimeToken.find_usable(session, purpose: :sign_in_challenge)
      user = record&.subject
      valid = record.present? &&
        @realm.owns?(user) &&
        user.active? &&
        record.data["challenge"] == challenge &&
        record.data["app_client_id"] == @app_client&.id

      raise ApiError.new(:invalid_challenge) unless valid

      record
    end

    def verify_otp!(user, code)
      raise ApiError.new(:too_many_attempts) if Lockout.new(owner: @realm.owner, configuration: @configuration).locked?(user.email)

      Mfa::Verifier.new(user: user, ip: @ip, user_agent: @user_agent, app_client: @app_client).verify!(code)
    end
  end
end
