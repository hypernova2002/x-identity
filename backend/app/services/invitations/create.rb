module Invitations
  class Create
    # @param inviter [User]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(inviter:, ip: nil, user_agent: nil)
      @inviter = inviter
      @account = inviter.account
      @ip = ip
      @user_agent = user_agent
    end

    # Invites an email to the account, replacing any earlier pending invitation for it.
    # @param email [String]
    # @param role [String]
    # @return [Invitation]
    # @raise [ApiError] `forbidden`, `email_taken` or `validation_failed`
    def call(email:, role:)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@inviter).grant_role?(role)
      raise ApiError.new(:email_taken) if @account.users.exists?(email: email)

      invitation, token = Invitation.transaction do
        @account.invitations.pending.where(email: email).find_each(&:revoke!)
        issued = Invitation.issue!(account: @account, invited_by: @inviter, email: email, role: role)
        @account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "invitation.created", actor: @inviter, target: issued.first, metadata: { role: role })
        issued
      end

      InvitationMailer.invitation(invitation, token).deliver_later
      invitation
    rescue ActiveRecord::RecordInvalid => error
      raise ApiError.from_record(error.record)
    end
  end
end
