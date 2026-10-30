module Mfa
  # Setting up, turning off and recovering a user's one-time-password credential.
  class OtpEnrollment
    # @param user [User, EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(user:, ip: nil, user_agent: nil)
      @user = user
      @realm = user.realm
      @ip = ip
      @user_agent = user_agent
    end

    # Creates a new unconfirmed credential with the realm's OTP method and settings, replacing any
    # earlier unconfirmed one.
    # @return [Enrollment]
    # @raise [ApiError] `mfa_already_enabled`
    def start
      raise ApiError.new(:mfa_already_enabled) if @user.mfa_enabled?

      configuration = @realm.auth_configuration

      credential = OtpCredential.transaction do
        OtpCredential.where(subject: @user).delete_all
        OtpCredential.generate(
          subject: @user, otp_type: configuration.otp_method, digits: configuration.otp_digits, step_seconds: configuration.otp_step_seconds
        ).tap(&:save!)
      end
      @user.association(:otp_credential).reset

      uri = credential.provisioning_uri(account_name: @realm.display_name, label: @user.email)
      Enrollment.new(
        otp_type: credential.otp_type,
        digits: credential.digits,
        step_seconds: credential.otp_type_totp? ? credential.step_seconds : nil,
        secret: credential.secret,
        provisioning_uri: uri,
        qr_code_svg: RQRCode::QRCode.new(uri).as_svg(module_size: 4, standalone: true, use_path: true)
      )
    end

    # Wrong codes here don't count towards disabling the user: they're still setting up.
    # @param code [String] a code from the user's authenticator app or token
    # @return [Array<String>] new recovery codes, shown to the user once
    # @raise [ApiError] `invalid_otp`
    def confirm(code:)
      configuration = @realm.auth_configuration
      credential = OtpCredential.find_by(subject: @user, confirmed_at: nil)
      verified = credential&.verify(code, drift_steps: configuration.otp_drift_steps, look_ahead: configuration.otp_hotp_look_ahead)
      raise ApiError.new(:invalid_otp) unless verified

      codes = OtpCredential.transaction do
        credential.confirm!
        record("mfa_enabled")
        RecoveryCode.regenerate_for!(@user)
      end
      @user.association(:otp_credential).reset

      codes
    end

    # @param current_password [String]
    # @param code [String] a one-time or recovery code
    # @raise [ApiError] `mfa_required_by_policy`, `validation_failed` or `invalid_otp`
    def disable(current_password:, code:)
      raise ApiError.new(:mfa_required_by_policy) if @realm.auth_configuration.mfa_required?
      raise ApiError.new(:not_found) unless @user.mfa_enabled?

      verify_password!(current_password)
      Verifier.new(user: @user, ip: @ip, user_agent: @user_agent).verify!(code)

      OtpCredential.transaction do
        @user.remove_mfa!
        record("mfa_disabled")
      end
    end

    # @param code [String] a one-time or recovery code
    # @return [Array<String>]
    def regenerate_recovery_codes(code:)
      raise ApiError.new(:not_found) unless @user.mfa_enabled?
      Verifier.new(user: @user, ip: @ip, user_agent: @user_agent).verify!(code)

      RecoveryCode.transaction do
        RecoveryCode.regenerate_for!(@user).tap { record("recovery_codes_regenerated") }
      end
    end

    private

    def verify_password!(password)
      return if Passwords::Hasher.new.matches?(password, @user.password_digest)

      raise ApiError.validation(:current_password, :incorrect)
    end

    def record(event)
      @realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "#{@realm.event_prefix}.#{event}", actor: @user, target: @user)
    end
  end
end
