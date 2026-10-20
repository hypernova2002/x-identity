module Auth
  # Answers a sign-in challenge issued by {SignInFlow}. A session token stays valid across wrong
  # answers (failures count towards lockout) and is consumed only once the challenge is passed.
  class ChallengeResponse
    # @param account [Account]
    def initialize(account:)
      @account = account
      @configuration = account.auth_configuration!
    end

    # @param session [String]
    # @param challenge [String] one of {SignInFlow::CHALLENGES}
    # @param code [String, nil] for `totp` and `mfa_setup`
    # @param new_password [String, nil] for `new_password`
    # @return [SignInResult]
    def call(session:, challenge:, code: nil, new_password: nil)
      record = find_session!(session, challenge)
      user = record.subject
      amr = record.data["amr"]
      recovery_codes = nil

      case challenge
      when "totp"
        verify_otp!(user, code)
        amr |= [ "otp" ]
      when "new_password"
        Users::PasswordChange.new(user: user).set_password!(new_password)
      when "mfa_setup"
        recovery_codes = Mfa::TotpEnrollment.new(user: user).confirm(code: code)
        amr |= [ "otp" ]
      end

      raise ApiError.new(:invalid_challenge) unless record.consume!

      SignInFlow.new(account: @account).continue(
        user: user,
        amr: amr,
        authenticated_at: Time.iso8601(record.data["authenticated_at"]),
        recovery_codes: recovery_codes
      )
    end

    # Starts TOTP enrolment for a user answering the `mfa_setup` challenge.
    # @param session [String]
    # @return [Mfa::Enrollment]
    def start_mfa_setup(session:)
      record = find_session!(session, "mfa_setup")
      Mfa::TotpEnrollment.new(user: record.subject).start
    end

    private

    def find_session!(session, challenge)
      record = OneTimeToken.find_usable(session, purpose: :sign_in_challenge)
      user = record&.subject
      valid = record.present? &&
        user.is_a?(User) &&
        user.account_id == @account.id &&
        user.active? &&
        record.data["challenge"] == challenge

      raise ApiError.new(:invalid_challenge) unless valid

      record
    end

    def verify_otp!(user, code)
      lockout = Lockout.new(owner: @account, configuration: @configuration)
      raise ApiError.new(:too_many_attempts) if lockout.locked?(user.email)
      return lockout.reset(user.email) if Mfa::Verifier.new(user: user).verify(code)

      lockout.register_failure(user.email)
      AuditEvents::Recorder.new(account: @account).record(action: "user.mfa_failed", actor: user, target: user)
      raise ApiError.new(:invalid_otp)
    end
  end
end
