module Mfa
  # Checks a one-time (TOTP or HOTP) or recovery code. Too many consecutive wrong codes disable the user, since only
  # someone who already has the password (or a session) can reach these checks. The account's last
  # active owner is locked out temporarily instead, so the account always keeps an owner.
  class Verifier
    # @param user [User, EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param app_client [AppClient, nil] the app client an end user is signing in through
    def initialize(user:, ip: nil, user_agent: nil, app_client: nil)
      @user = user
      @realm = user.realm
      @ip = ip
      @user_agent = user_agent
      @app_client = app_client
    end

    # @param code [String, nil]
    # @return [true]
    # @raise [ApiError] `invalid_otp`, `user_disabled` when this failure reached the limit, or
    #   `too_many_attempts` when the last active owner was locked out instead
    def verify!(code)
      if matches?(code)
        @user.reset_mfa_failures!
        return true
      end

      failures = @user.register_mfa_failure!
      record("mfa_failed", failures: failures)
      raise ApiError.new(:invalid_otp) if failures < @realm.auth_configuration.mfa_max_failed_attempts

      last_active_owner? ? lock_out! : disable!
    end

    private

    def matches?(code)
      credential = OtpCredential.confirmed.find_by(subject: @user)
      return false if credential.nil? || code.blank?

      configuration = @realm.auth_configuration
      credential.verify(code, drift_steps: configuration.otp_drift_steps, look_ahead: configuration.otp_hotp_look_ahead) ||
        RecoveryCode.consume(@user, code)
    end

    def last_active_owner?
      @user.is_a?(User) && @user.owner? && !@user.account.users.owner.active.where.not(id: @user.id).exists?
    end

    def disable!
      @user.disable!
      @user.reset_mfa_failures!
      mailer = @user.is_a?(EndUser) ? EndUserMailer : UserMailer
      mailer.disabled_after_mfa_failures(@user).deliver_later
      record("disabled_after_mfa_failures")
      raise ApiError.new(:user_disabled)
    end

    def lock_out!
      Auth::Lockout.new(owner: @realm.owner, configuration: @realm.auth_configuration).lock!(@user.email)
      @user.reset_mfa_failures!
      record("locked_after_mfa_failures")
      raise ApiError.new(:too_many_attempts)
    end

    def record(event, **metadata)
      @realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
        .record(action: "#{@realm.event_prefix}.#{event}", actor: @user, target: @user, metadata: metadata)
    end
  end
end
