# Emails to a known end user, queued by admins (invitations).
class EndUserEmailJob < TransactionalEmailJob
  # @param kind [String] "invitation"
  # @param end_user_id [Integer]
  def perform(kind:, end_user_id:)
    end_user = EndUser.active.find_by(id: end_user_id)
    return if end_user.nil?

    case kind
    when "invitation" then EndUsers::Emails.new(project: end_user.project).send_invitation(end_user) unless end_user.password_set?
    else raise ArgumentError, "unknown email kind #{kind}"
    end
  end
end
