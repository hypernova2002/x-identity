class PasswordResetEmailJob < TransactionalEmailJob
  # @param account_id [Integer]
  # @param email [String]
  # @param ip [String, nil] of the request that asked for the reset, for the audit log
  # @param user_agent [String, nil]
  def perform(account_id:, email:, ip: nil, user_agent: nil)
    account = Account.find_by(id: account_id)
    return if account.nil?

    Auth::PasswordReset.new(account: account, request_context: request_context(ip, user_agent)).deliver(email: email)
  end
end
