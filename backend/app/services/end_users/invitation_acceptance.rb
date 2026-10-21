module EndUsers
  # An end user created by an admin sets their first password with the code (or link token) from
  # their invitation. Their email counts as verified, since the invitation reached it.
  class InvitationAcceptance
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

    # @param password [String]
    # @param email [String, nil]
    # @param code [String, nil]
    # @param token [String, nil]
    # @return [EndUser]
    # @raise [ApiError] `invalid_code` or `validation_failed`
    def accept(password:, email: nil, code: nil, token: nil)
      record = CodeRedemption.new(project: @project, ip: @ip, user_agent: @user_agent).find!(purpose: :invitation, email: email, code: code, token: token)
      end_user = record.subject

      EndUser.transaction do
        Users::PasswordChange.new(user: end_user, ip: @ip, user_agent: @user_agent).set_password!(password, field: :password)
        raise ApiError.new(:invalid_code) unless record.consume!

        end_user.verify_email!
      end

      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
        .record(action: "end_user.invitation_accepted", actor: end_user, target: end_user)
      end_user
    end
  end
end
