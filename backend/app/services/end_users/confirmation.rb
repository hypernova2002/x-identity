module EndUsers
  # Confirms an end user's email address with the code (or link token) from their confirmation email.
  class Confirmation
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

    # @param email [String, nil]
    # @param code [String, nil]
    # @param token [String, nil]
    # @return [EndUser]
    # @raise [ApiError] `invalid_code` or `validation_failed`
    def confirm(email: nil, code: nil, token: nil)
      record = CodeRedemption.new(project: @project, ip: @ip, user_agent: @user_agent).find!(purpose: :email_verification, email: email, code: code, token: token)
      end_user = record.subject
      EndUser.transaction do
        raise ApiError.new(:invalid_code) unless record.consume!

        end_user.verify_email!
        recorder.record(action: "end_user.email_verified", actor: end_user, target: end_user)
      end
      end_user
    end

    # Queues a new confirmation code. The lookup happens in the job, so the response never reveals
    # whether the address exists.
    # @param email [String]
    def resend(email:)
      EndUserLookupEmailJob.perform_later(
        kind: "confirmation",
        project_id: @project.id,
        email: email,
        ip: @ip,
        user_agent: @user_agent
      )
    end

    # Sends a confirmation code if the address belongs to an active, unconfirmed end user.
    # @param email [String]
    def deliver(email:)
      end_user = @project.end_users.active.find_by(email: email)
      return if end_user.nil? || end_user.email_verified?

      Emails.new(project: @project).send_confirmation(end_user)
    end

    private

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
    end
  end
end
