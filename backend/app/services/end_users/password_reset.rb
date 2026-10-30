module EndUsers
  class PasswordReset
    # @param project [Project]
    # @param app_client [AppClient, nil]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, app_client: nil, ip: nil, user_agent: nil)
      @project = project
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
    end

    # Queues a reset code. The lookup happens in the job, so the response never reveals whether
    # the address exists.
    # @param email [String]
    def request(email:)
      EndUserLookupEmailJob.perform_later(
        kind: "password_reset",
        project_id: @project.id,
        email: email,
        ip: @ip,
        user_agent: @user_agent
      )
    end

    # Sends a reset code if the address belongs to an active end user.
    # @param email [String]
    def deliver(email:)
      end_user = @project.end_users.active.find_by(email: email)
      return if end_user.nil?

      Emails.new(project: @project).send_password_reset(end_user)
      recorder.record(action: "end_user.password_reset_requested", target: end_user)
    end

    # The code is checked first and the token consumed only after the new password is accepted,
    # so a password that breaks the rules can be corrected with the same code.
    # @param password [String]
    # @param email [String, nil]
    # @param code [String, nil]
    # @param token [String, nil]
    # @return [EndUser]
    # @raise [ApiError] `invalid_code` or `validation_failed`
    def confirm(password:, email: nil, code: nil, token: nil)
      record = CodeRedemption.new(project: @project, ip: @ip, user_agent: @user_agent).find!(purpose: :password_reset, email: email, code: code, token: token)
      end_user = record.subject

      EndUser.transaction do
        Users::PasswordChange.new(user: end_user, ip: @ip, user_agent: @user_agent).set_password!(password, field: :password)
        raise ApiError.new(:invalid_code) unless record.consume!

        end_user.verify_email!
        end_user.revoke_all_sessions!
        end_user.start_passkey_recovery! if end_user.webauthn_credentials.exists?
        recorder.record(action: "end_user.password_reset", actor: end_user, target: end_user)
      end

      Auth::Lockout.new(owner: @project, configuration: @project.auth_configuration!).reset(end_user.email)
      end_user
    end

    private

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
    end
  end
end
