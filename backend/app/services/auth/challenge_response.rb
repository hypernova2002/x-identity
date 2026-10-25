module Auth
  # Answers a sign-in challenge issued by {SignInFlow}. A session token stays valid across wrong
  # answers (failures count towards lockout) and is consumed only once the challenge is passed.
  class ChallengeResponse
    # @param context [SignInContext] the app client and hosted login interaction must be the ones the sign-in started with
    def initialize(context:)
      @context = context
      @realm = context.realm
      @configuration = context.configuration
    end

    # @param session [String]
    # @param challenge [String] one of {Challenges::ALL}
    # @param code [String, nil] for `otp` and `mfa_setup`
    # @param new_password [String, nil] for `new_password`
    # @param authentication_id [String, nil] for `passkey`: from {#passkey_options}
    # @param registration_id [String, nil] for `passkey_setup`: from {#start_passkey_setup}
    # @param credential [Hash, nil] for `passkey` and `passkey_setup`: the browser's answer or new passkey, as JSON
    # @return [SignInResult]
    def call(session:, challenge:, code: nil, new_password: nil, authentication_id: nil, registration_id: nil, credential: nil)
      record = find_session!(session, challenge)
      user = record.subject
      amr = record.data["amr"]
      recovery_codes = nil

      case challenge
      when Challenges::OTP
        verify_otp!(user, code)
        amr |= [ Amr::OTP ]
      when Challenges::PASSKEY
        _user, passkey_amr = passkey_authentication(user).verify(authentication_id: authentication_id, credential: credential.to_h, user: user)
        amr |= passkey_amr
      when Challenges::PASSKEY_SETUP
        passkey = passkey_registration(user, record).finish(registration_id: registration_id.to_s, credential: credential.to_h)
        amr |= passkey.amr
      when Challenges::NEW_PASSWORD
        Users::PasswordChange.new(user: user, **@context.client_info).set_password!(new_password)
      when Challenges::MFA_SETUP
        recovery_codes = Mfa::OtpEnrollment.new(user: user, **@context.client_info).confirm(code: code)
        amr |= [ Amr::OTP ]
      end

      raise ApiError.new(:invalid_challenge) unless record.consume!

      SignInFlow.new(context: @context).continue(
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
      user = find_session!(session, Challenges::PASSKEY).subject
      passkey_authentication(user).options(user: user)
    end

    # Options for creating the passkey that answers the `passkey_setup` challenge.
    # @param session [String]
    # @return [Hash] see {Passkeys::Registration#options}
    # @raise [ApiError] `invalid_challenge` or `passkeys_unavailable`
    def start_passkey_setup(session:)
      record = find_session!(session, Challenges::PASSKEY_SETUP)
      passkey_registration(record.subject, record).options
    end

    # Starts OTP enrolment for a user answering the `mfa_setup` challenge.
    # @param session [String]
    # @return [Mfa::Enrollment]
    def start_mfa_setup(session:)
      record = find_session!(session, Challenges::MFA_SETUP)
      Mfa::OtpEnrollment.new(user: record.subject, **@context.client_info).start
    end

    private

    def find_session!(session, challenge)
      record = OneTimeToken.find_usable(session, purpose: :sign_in_challenge)
      user = record&.subject
      valid = record.present? &&
        @realm.owns?(user) &&
        user.active? &&
        Challenge.new(name: record.data["challenge"], mfa_methods: record.data["mfa_methods"]).answered_by?(challenge) &&
        record.data["app_client_id"] == @context.app_client&.id &&
        record.data["interaction_id"] == @context.interaction&.id

      raise ApiError.new(:invalid_challenge) unless valid

      record
    end

    # The sign-in in progress counts as the recent sign-in adding a passkey needs.
    def passkey_registration(user, record)
      Passkeys::Registration.new(
        user: user, relying_party: passkey_relying_party!(user), authenticated_at: Time.iso8601(record.data["authenticated_at"]), **@context.client_info
      )
    end

    def passkey_authentication(user)
      Passkeys::Authentication.new(realm: @realm, relying_party: passkey_relying_party!(user))
    end

    def passkey_relying_party!(user)
      @context.passkey_relying_party(user) || raise(ApiError.new(:passkeys_unavailable))
    end

    def verify_otp!(user, code)
      raise ApiError.new(:too_many_attempts) if Lockout.new(owner: @realm.owner, configuration: @configuration).locked?(user.email)

      Mfa::Verifier.new(user: user, app_client: @context.app_client, **@context.client_info).verify!(code)
    end
  end
end
