module Mfa
  class TotpEnrollment
    # @param user [User]
    def initialize(user:)
      @user = user
    end

    # Creates a new unconfirmed TOTP credential, replacing any earlier unconfirmed one.
    # @return [Enrollment]
    # @raise [ApiError] `mfa_already_enabled`
    def start
      raise ApiError.new(:mfa_already_enabled) if @user.mfa_enabled?

      credential = OtpCredential.transaction do
        OtpCredential.where(subject: @user).delete_all
        OtpCredential.generate(subject: @user).tap(&:save!)
      end
      @user.association(:otp_credential).reset

      uri = credential.provisioning_uri(account_name: @user.account.name, label: @user.email)
      Enrollment.new(
        secret: credential.secret,
        provisioning_uri: uri,
        qr_code_svg: RQRCode::QRCode.new(uri).as_svg(module_size: 4, standalone: true, use_path: true)
      )
    end

    # @param code [String] a code from the user's authenticator app
    # @return [Array<String>] new recovery codes, shown to the user once
    # @raise [ApiError] `invalid_otp`
    def confirm(code:)
      credential = OtpCredential.find_by(subject: @user, confirmed_at: nil)
      raise ApiError.new(:invalid_otp) unless credential&.verify(code)

      codes = OtpCredential.transaction do
        credential.confirm!
        RecoveryCode.regenerate_for!(@user)
      end
      @user.association(:otp_credential).reset

      recorder.record(action: "user.mfa_enabled", actor: @user, target: @user)
      codes
    end

    # @param current_password [String]
    # @param code [String] a TOTP or recovery code
    # @raise [ApiError] `mfa_required_by_policy`, `validation_failed` or `invalid_otp`
    def disable(current_password:, code:)
      raise ApiError.new(:mfa_required_by_policy) if @user.account.auth_configuration!.mfa_required?
      raise ApiError.new(:not_found) unless @user.mfa_enabled?

      verify_password!(current_password)
      raise ApiError.new(:invalid_otp) unless Verifier.new(user: @user).verify(code)

      OtpCredential.transaction do
        OtpCredential.where(subject: @user).delete_all
        RecoveryCode.where(subject: @user).delete_all
      end
      @user.association(:otp_credential).reset

      recorder.record(action: "user.mfa_disabled", actor: @user, target: @user)
    end

    # @param code [String] a TOTP or recovery code
    # @return [Array<String>]
    def regenerate_recovery_codes(code:)
      raise ApiError.new(:not_found) unless @user.mfa_enabled?
      raise ApiError.new(:invalid_otp) unless Verifier.new(user: @user).verify(code)

      codes = RecoveryCode.regenerate_for!(@user)
      recorder.record(action: "user.recovery_codes_regenerated", actor: @user, target: @user)
      codes
    end

    private

    def verify_password!(password)
      return if Passwords::Hasher.new.matches?(password, @user.password_digest)

      raise ApiError.validation(current_password: "is incorrect")
    end

    def recorder
      AuditEvents::Recorder.new(account: @user.account)
    end
  end
end
