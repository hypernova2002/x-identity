module Auth
  class PasswordReset
    # @param account [Account]
    # @param request_context [RequestContext] who asked, for the audit log
    def initialize(account:, request_context: RequestContext.blank)
      @account = account
      @request_context = request_context
    end

    # Queues a reset email. The lookup happens in the job, so callers learn nothing about which
    # emails exist, not even from response timing.
    # @param email [String]
    def request(email:)
      PasswordResetEmailJob.perform_later(
        account_id: @account.id,
        email: normalize(email),
        ip: @request_context.ip,
        user_agent: @request_context.user_agent
      )
    end

    # Emails a reset link if the address belongs to an active user; does nothing otherwise.
    # @param email [String]
    def deliver(email:)
      user = @account.users.active.find_by(email: normalize(email))
      return if user.nil?

      _record, token = OneTimeToken.issue!(subject: user, purpose: :password_reset)
      UserMailer.password_reset(user, token).deliver_now
      recorder.record(action: "user.password_reset_requested", target: user)
    end

    # The token is checked first and consumed only after the new password is accepted, so a
    # password that breaks the rules can be corrected without requesting another email.
    # @param token [String]
    # @param password [String]
    # @return [User]
    # @raise [ApiError] `invalid_token` or `validation_failed`
    def reset(token:, password:)
      record = OneTimeToken.find_usable(token, purpose: :password_reset)
      user = record&.subject
      raise ApiError.new(:invalid_token) unless user.is_a?(User) && user.account_id == @account.id && user.active?

      User.transaction do
        Users::PasswordChange.new(user: user).set_password!(password, field: :password)
        raise ApiError.new(:invalid_token) unless record.consume!

        user.verify_email!
        user.revoke_all_sessions!
      end

      Lockout.new(owner: @account, configuration: @account.auth_configuration!).reset(user.email)
      recorder.record(action: "user.password_reset", actor: user, target: user)
      user
    end

    private

    def normalize(email)
      email.to_s.strip.downcase
    end

    def recorder
      AuditEvents::Recorder.new(account: @account, request_context: @request_context)
    end
  end
end
