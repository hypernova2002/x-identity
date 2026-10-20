module Auth
  class EmailVerification
    # @param account [Account]
    # @param request_context [RequestContext] who asked, for the audit log
    def initialize(account:, request_context: RequestContext.blank)
      @account = account
      @request_context = request_context
    end

    # Queues a verification email. The lookup happens in the job, so callers learn nothing about
    # which emails exist, not even from response timing.
    # @param email [String]
    def request(email:)
      VerificationEmailJob.perform_later(account_id: @account.id, email: email.to_s.strip.downcase)
    end

    # Emails a verification link if the address belongs to an active, unverified user; does
    # nothing otherwise.
    # @param email [String]
    def deliver(email:)
      user = @account.users.active.find_by(email: email.to_s.strip.downcase)
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
      AuditEvents::Recorder.new(account: @account, request_context: @request_context)
        .record(action: "user.email_verified", actor: user, target: user)
      user
    end
  end
end
