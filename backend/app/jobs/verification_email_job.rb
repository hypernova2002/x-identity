class VerificationEmailJob < TransactionalEmailJob
  # @param account_id [Integer]
  # @param email [String]
  def perform(account_id:, email:)
    account = Account.find_by(id: account_id)
    return if account.nil?

    Auth::EmailVerification.new(account: account).deliver(email: email)
  end
end
