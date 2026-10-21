module EndUsers
  # Issues codes and sends the emails end users receive. Called from background jobs, so tokens
  # and codes are generated and sent in the same place and never sit in the job queue.
  class Emails
    # @param project [Project]
    def initialize(project:)
      @project = project
      @blocked_code = CodeThrottle.new(project: project).method(:code_blocked?)
    end

    # @param end_user [EndUser]
    def send_confirmation(end_user)
      issued = OneTimeToken.issue_with_code!(subject: end_user, purpose: :email_verification, reject_code: @blocked_code)
      EndUserMailer.confirmation(end_user, issued.code, @project.email_link(:confirm_sign_up_url, issued.token)).deliver_now
    end

    # @param end_user [EndUser]
    def send_password_reset(end_user)
      issued = OneTimeToken.issue_with_code!(subject: end_user, purpose: :password_reset, reject_code: @blocked_code)
      EndUserMailer.password_reset(end_user, issued.code, @project.email_link(:reset_password_url, issued.token)).deliver_now
    end

    # @param end_user [EndUser]
    def send_invitation(end_user)
      issued = OneTimeToken.issue_with_code!(subject: end_user, purpose: :invitation, reject_code: @blocked_code)
      EndUserMailer.invitation(end_user, issued.code, @project.email_link(:accept_invitation_url, issued.token)).deliver_now
    end

    # Tells the owner of a confirmed address that someone tried to sign up with it.
    # @param end_user [EndUser]
    def send_existing_account_notice(end_user)
      EndUserMailer.existing_account(end_user).deliver_now
    end

    # @param end_user [EndUser]
    # @param new_email [String]
    def send_email_change(end_user, new_email)
      issued = OneTimeToken.issue_with_code!(
        subject: end_user, purpose: :email_change, data: { "new_email" => new_email }, reject_code: @blocked_code
      )
      EndUserMailer.email_change_code(end_user, new_email, issued.code).deliver_now
      EndUserMailer.email_change_notice(end_user, new_email).deliver_now
    end
  end
end
