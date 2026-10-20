module Invitations
  class Create
    # @param inviter [User]
    def initialize(inviter:)
      @inviter = inviter
      @account = inviter.account
    end

    # Invites an email to the account, replacing any earlier pending invitation for it.
    # @param email [String]
    # @param role [String]
    # @return [Invitation]
    # @raise [ApiError] `forbidden`, `email_taken` or `validation_failed`
    def call(email:, role:)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@inviter).grant_role?(role)

      email = email.to_s.strip.downcase
      raise ApiError.new(:email_taken) if @account.users.exists?(email: email)

      invitation, token = Invitation.transaction do
        @account.invitations.pending.where(email: email).find_each(&:revoke!)
        Invitation.issue!(account: @account, invited_by: @inviter, email: email, role: role)
      end

      InvitationMailer.invitation(invitation, token).deliver_later
      AuditEvents::Recorder.new(account: @account).record(action: "invitation.created", actor: @inviter, target: invitation, metadata: { role: role })
      invitation
    rescue ActiveRecord::RecordInvalid => error
      raise ApiError.from_record(error.record)
    end
  end
end
