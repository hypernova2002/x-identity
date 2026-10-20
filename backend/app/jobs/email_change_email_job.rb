class EmailChangeEmailJob < TransactionalEmailJob
  # @param user_id [Integer]
  # @param new_email [String]
  # @param ip [String, nil] of the request that asked for the change, for the audit log
  # @param user_agent [String, nil]
  def perform(user_id:, new_email:, ip: nil, user_agent: nil)
    user = User.active.find_by(id: user_id)
    return if user.nil?

    Users::EmailChange.new(account: user.account, request_context: request_context(ip, user_agent)).deliver(user: user, new_email: new_email)
  end
end
