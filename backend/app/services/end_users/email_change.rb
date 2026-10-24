module EndUsers
  # A signed-in end user changing their email. A code goes to the new address; the old address
  # keeps working until the code is confirmed. Whether the new address is already taken is decided
  # in a background job, so the response never reveals it.
  class EmailChange
    # @param end_user [EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(end_user:, ip: nil, user_agent: nil)
      @end_user = end_user
      @project = end_user.project
      @ip = ip
      @user_agent = user_agent
    end

    # @param new_email [String]
    # @param current_password [String]
    # @param otp_code [String, nil] required when the end user has MFA turned on
    # @raise [ApiError] `validation_failed` or `invalid_otp`
    def request(new_email:, current_password:, otp_code: nil)
      raise ApiError.validation(current_password: "is incorrect") unless Passwords::Hasher.new.matches?(current_password, @end_user.password_digest)
      Mfa::Verifier.new(user: @end_user, ip: @ip, user_agent: @user_agent).verify!(otp_code) if @end_user.mfa_enabled?
      raise ApiError.validation(new_email: "must be different from your current email") if new_email == @end_user.email

      EndUserEmailChangeJob.perform_later(
        end_user_id: @end_user.id,
        new_email: new_email,
        ip: @ip,
        user_agent: @user_agent
      )
    end

    # Sends the code to the new address and a notice to the old one, unless the new address belongs
    # to another end user in the project, in which case nothing is sent. Run by {EndUserEmailChangeJob}.
    # @param new_email [String]
    def deliver(new_email:)
      if @project.end_users.exists?(email: new_email)
        recorder.record(action: "end_user.email_change_blocked", actor: @end_user, target: @end_user, metadata: { new_email: new_email, reason: "email_taken" })
        return
      end

      Emails.new(project: @project).send_email_change(@end_user, new_email)
      recorder.record(action: "end_user.email_change_requested", actor: @end_user, target: @end_user, metadata: { new_email: new_email })
    end

    # @param code [String]
    # @param keep_session_id [String] the current session, which stays signed in
    # @return [EndUser]
    # @raise [ApiError] `invalid_code`, `email_taken`, or `too_many_attempts` when the caller's IP is blocked
    def confirm(code:, keep_session_id:)
      record = OneTimeToken.current_for(@end_user, purpose: :email_change)
      max_attempts = @project.auth_configuration!.email_code_max_attempts
      matched = CodeThrottle.new(project: @project, ip: @ip, user_agent: @user_agent).attempt(email: @end_user.email, code: code) do
        record&.code_matches?(code, max_attempts: max_attempts) || false
      end
      raise ApiError.new(:invalid_code) unless matched

      old_email = @end_user.email
      new_email = record.data.fetch("new_email")
      raise ApiError.new(:email_taken) if @project.end_users.exists?(email: new_email)

      EndUser.transaction do
        raise ApiError.new(:invalid_code) unless record.consume!

        @end_user.update!(email: new_email, email_verified_at: Time.current)
        @end_user.revoke_other_sessions!(keep_session_id: keep_session_id)
      end

      recorder.record(action: "end_user.email_changed", actor: @end_user, target: @end_user, metadata: { old_email: old_email, new_email: new_email })
      @end_user
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:email_taken)
    end

    private

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
