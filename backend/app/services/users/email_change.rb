module Users
  # Changes a user's email only after the new address is confirmed. The old address keeps working
  # until then and is notified that a change was requested.
  class EmailChange
    # @param account [Account]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(account:, ip: nil, user_agent: nil)
      @account = account
      @ip = ip
      @user_agent = user_agent
    end

    # Checks the user's own credentials, then queues the confirmation email. Whether the new
    # address is already taken is decided in the job, so the response never reveals it.
    # @param user [User]
    # @param new_email [String]
    # @param current_password [String]
    # @param otp_code [String, nil] required when the user has MFA turned on
    # @raise [ApiError] `validation_failed` or `invalid_otp`
    def request(user:, new_email:, current_password:, otp_code: nil)
      raise ApiError.validation(current_password: "is incorrect") unless Passwords::Hasher.new.matches?(current_password, user.password_digest)
      Mfa::Verifier.new(user: user, ip: @ip, user_agent: @user_agent).verify!(otp_code) if user.mfa_enabled?
      raise ApiError.validation(new_email: "is invalid") unless new_email.match?(URI::MailTo::EMAIL_REGEXP) && new_email.length <= 254
      raise ApiError.validation(new_email: "must be different from your current email") if new_email == user.email

      EmailChangeEmailJob.perform_later(
        user_id: user.id,
        new_email: new_email,
        ip: @ip,
        user_agent: @user_agent
      )
    end

    # Sends the confirmation link to the new address and a notice to the old one, unless the new
    # address already belongs to another user in the account, in which case nothing is sent.
    # @param user [User]
    # @param new_email [String]
    def deliver(user:, new_email:)
      if @account.users.exists?(email: new_email)
        recorder.record(action: "user.email_change_blocked", actor: user, target: user, metadata: { new_email: new_email, reason: "email_taken" })
        return
      end

      _record, token = OneTimeToken.issue!(subject: user, purpose: :email_change, data: { "new_email" => new_email })
      UserMailer.email_change_confirmation(user, new_email, token).deliver_now
      UserMailer.email_change_notice(user, new_email).deliver_now
      recorder.record(action: "user.email_change_requested", actor: user, target: user, metadata: { new_email: new_email })
    end

    # @param token [String]
    # @return [User]
    # @raise [ApiError] `invalid_token` or `email_taken`
    def confirm(token:)
      record = OneTimeToken.find_usable(token, purpose: :email_change)
      user = record&.subject
      raise ApiError.new(:invalid_token) unless user.is_a?(User) && user.account_id == @account.id && user.active?

      old_email = user.email
      new_email = record.data.fetch("new_email")
      raise ApiError.new(:email_taken) if @account.users.exists?(email: new_email)

      User.transaction do
        raise ApiError.new(:invalid_token) unless record.consume!

        user.update!(email: new_email, email_verified_at: Time.current)
        user.revoke_all_sessions!
      end

      recorder.record(action: "user.email_changed", actor: user, target: user, metadata: { old_email: old_email, new_email: new_email })
      user
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:email_taken)
    end

    private

    def recorder
      AuditEvents::Recorder.new(account: @account, ip: @ip, user_agent: @user_agent)
    end
  end
end
