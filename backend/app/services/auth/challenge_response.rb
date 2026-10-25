module Auth
  # Answers a sign-in challenge issued by {SignInFlow}. A session token stays valid across wrong
  # answers (failures count towards lockout) and is consumed only once the challenge is passed.
  class ChallengeResponse
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param app_client [AppClient, nil] must be the client the sign-in started with
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param interaction [OneTimeToken, nil] must be the hosted login interaction the sign-in started in
    def initialize(realm:, app_client: nil, ip: nil, user_agent: nil, interaction: nil)
      @realm = realm
      @app_client = app_client
      @interaction = interaction
      @ip = ip
      @user_agent = user_agent
      @configuration = realm.auth_configuration
    end

    # @param session [String]
    # @param challenge [String] one of {SignInFlow::CHALLENGES}
    # @param code [String, nil] for `otp` and `mfa_setup`
    # @param new_password [String, nil] for `new_password`
    # @param authentication_id [String, nil] for `passkey`: from {#passkey_options}
    # @param credential [Hash, nil] for `passkey`: the browser's answer, as JSON
    # @return [SignInResult]
    def call(session:, challenge:, code: nil, new_password: nil, authentication_id: nil, credential: nil)
      record = find_session!(session, challenge)
      user = record.subject
      amr = record.data["amr"]
      recovery_codes = nil

      case challenge
      when "otp"
        verify_otp!(user, code)
        amr |= [ "otp" ]
      when "passkey"
        _user, passkey_amr = passkey_authentication(user).verify(authentication_id: authentication_id, credential: credential.to_h, user: user)
        amr |= passkey_amr
      when "new_password"
        Users::PasswordChange.new(user: user, ip: @ip, user_agent: @user_agent).set_password!(new_password)
      when "mfa_setup"
        recovery_codes = Mfa::OtpEnrollment.new(user: user, ip: @ip, user_agent: @user_agent).confirm(code: code)
        amr |= [ "otp" ]
      end

      raise ApiError.new(:invalid_challenge) unless record.consume!

      SignInFlow.new(realm: @realm, app_client: @app_client, ip: @ip, user_agent: @user_agent, interaction: @interaction).continue(
        user: user,
        amr: amr,
        authenticated_at: Time.iso8601(record.data["authenticated_at"]),
        recovery_codes: recovery_codes
      )
    end

    # Options for answering a second-factor challenge with one of the user's passkeys.
    # @param session [String]
    # @return [Hash] see {Passkeys::Authentication#options}
    # @raise [ApiError] `invalid_challenge` or `passkeys_unavailable`
    def passkey_options(session:)
      user = find_session!(session, "passkey").subject
      passkey_authentication(user).options(user: user)
    end

    # Starts OTP enrolment for a user answering the `mfa_setup` challenge.
    # @param session [String]
    # @return [Mfa::Enrollment]
    def start_mfa_setup(session:)
      record = find_session!(session, "mfa_setup")
      Mfa::OtpEnrollment.new(user: record.subject, ip: @ip, user_agent: @user_agent).start
    end

    private

    def find_session!(session, challenge)
      record = OneTimeToken.find_usable(session, purpose: :sign_in_challenge)
      user = record&.subject
      valid = record.present? &&
        @realm.owns?(user) &&
        user.active? &&
        answers?(record, challenge) &&
        record.data["app_client_id"] == @app_client&.id &&
        record.data["interaction_id"] == @interaction&.id

      raise ApiError.new(:invalid_challenge) unless valid

      record
    end

    # A passkey can answer any second-factor challenge that offers it.
    def answers?(record, challenge)
      record.data["challenge"] == challenge || (challenge == "passkey" && Array(record.data["mfa_methods"]).include?("passkey"))
    end

    def passkey_authentication(user)
      relying_party = Passkeys::RelyingParties.for_sign_in(user, interaction: @interaction, app_client: @app_client)
      raise ApiError.new(:passkeys_unavailable) unless relying_party

      Passkeys::Authentication.new(realm: @realm, relying_party: relying_party)
    end

    def verify_otp!(user, code)
      raise ApiError.new(:too_many_attempts) if Lockout.new(owner: @realm.owner, configuration: @configuration).locked?(user.email)

      Mfa::Verifier.new(user: user, ip: @ip, user_agent: @user_agent, app_client: @app_client).verify!(code)
    end
  end
end
