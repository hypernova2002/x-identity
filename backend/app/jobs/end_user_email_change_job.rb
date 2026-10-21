class EndUserEmailChangeJob < TransactionalEmailJob
  # @param end_user_id [Integer]
  # @param new_email [String]
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  def perform(end_user_id:, new_email:, ip: nil, user_agent: nil)
    end_user = EndUser.active.find_by(id: end_user_id)
    return if end_user.nil?

    EndUsers::EmailChange.new(end_user: end_user, ip: ip, user_agent: user_agent).deliver(new_email: new_email)
  end
end
