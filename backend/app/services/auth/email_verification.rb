module Auth
  class EmailVerification
    # @param account [Account]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(account:, ip: nil, user_agent: nil)
      @account = account
      @ip = ip
      @user_agent = user_agent
    end

    # Queues a verification email. The lookup happens in the job, so callers learn nothing about
    # which emails exist, not even from response timing.
    # @param email [String]
    def request(email:)
      VerificationEmailJob.perform_later(account_id: @account.id, email: email)
    end

    # Emails a verification link if the address belongs to an active, unverified user; does
    # nothing otherwise.
    # @param email [String]
    def deliver(email:)
      user = @account.users.active.find_by(email: email)
      return if user.nil? || user.email_verified?

      _record, token = OneTimeToken.issue!(subject: user, purpose: :email_verification)
      UserMailer.email_verification(user, token).deliver_now
    end

    # @param token [String]
    # @return [User]
    # @raise [ApiError] `invalid_token`
    def confirm(token:)
      record = OneTimeToken.find_usable(token, purpose: :email_verification)
      user = record&.subject
      raise ApiError.new(:invalid_token) unless user.is_a?(User) && user.account_id == @account.id && record.consume!

      user.verify_email!
      AuditEvents::Recorder.new(account: @account, ip: @ip, user_agent: @user_agent)
        .record(action: "user.email_verified", actor: user, target: user)
      user
    end
  end
end
