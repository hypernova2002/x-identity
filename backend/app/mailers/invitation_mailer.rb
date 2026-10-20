class InvitationMailer < ApplicationMailer
  def invitation(invitation, token)
    @invitation = invitation
    @url = console_url(invitation.account, "accept-invitation", token)
    mail(to: invitation.email, subject: "You've been invited to #{invitation.account.name} on x-identity")
  end
end
