module Invitations
  # Creates the invited user. Their email counts as verified, since the invitation reached it.
  class Accept
    # @param account [Account]
    def initialize(account:)
      @account = account
    end

    # @param token [String]
    # @param name [String]
    # @param password [String]
    # @return [User]
    # @raise [ApiError] `invalid_token`, `email_taken` or `validation_failed`
    def call(token:, name:, password:)
      invitation = @account.invitations.find_pending_by_token(token)
      raise ApiError.new(:invalid_token) if invitation.nil?
      raise ApiError.new(:email_taken) if @account.users.exists?(email: invitation.email)

      now = Time.current
      user = @account.users.new(
        name: name,
        email: invitation.email,
        role: invitation.role,
        email_verified_at: now,
        password_digest: "pending",
        password_changed_at: now
      )
      validate!(user, password)
      user.password_digest = Passwords::Hasher.new.digest(password)

      User.transaction do
        user.save!
        invitation.accept!
      end

      AuditEvents::Recorder.new(account: @account).record(action: "invitation.accepted", actor: user, target: user, metadata: { invitation_uid: invitation.uid })
      user
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:email_taken)
    end

    private

    def validate!(user, password)
      details = user.valid? ? [] : ApiError.from_record(user).details
      details += @account.auth_configuration!.password_violations(password).map { |message| { field: "password", message: message } }

      raise ApiError.new(:validation_failed, details: details) if details.any?
    end
  end
end
