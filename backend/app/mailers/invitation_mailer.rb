class InvitationMailer < ApplicationMailer
  # In the inviter's language, since the person invited hasn't chosen one yet.
  def invitation(invitation, token)
    @invitation = invitation
    @url = console_url(invitation.account, "accept-invitation", token)
    localized_mail(invitation.invited_by&.locale, to: invitation.email, account: invitation.account.name)
  end
end
