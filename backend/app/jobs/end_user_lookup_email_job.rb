# Emails that start from an address typed by someone who isn't signed in. The lookup happens here
# so the HTTP response is identical whether or not the address belongs to an end user.
class EndUserLookupEmailJob < TransactionalEmailJob
  KINDS = %w[confirmation password_reset].freeze

  # @param kind [String] one of {KINDS}
  # @param project_id [Integer]
  # @param email [String]
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  def perform(kind:, project_id:, email:, ip: nil, user_agent: nil)
    project = Project.find_by(id: project_id)
    return if project.nil?

    case kind
    when "confirmation" then EndUsers::Confirmation.new(project: project, ip: ip, user_agent: user_agent).deliver(email: email)
    when "password_reset" then EndUsers::PasswordReset.new(project: project, ip: ip, user_agent: user_agent).deliver(email: email)
    else raise ArgumentError, "unknown email kind #{kind}"
    end
  end
end
