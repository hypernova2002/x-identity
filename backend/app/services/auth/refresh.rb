module Auth
  # Exchanges a refresh token for a new token set. Each refresh token works once; presenting a
  # used one is treated as theft and revokes its whole family.
  class Refresh
    # @param account [Account]
    def initialize(account:)
      @account = account
      @configuration = account.auth_configuration!
    end

    # @param refresh_token [String]
    # @return [TokenSet]
    # @raise [ApiError] `invalid_token`, `session_expired` or `mfa_required`
    def call(refresh_token:)
      record = RefreshToken.find_by_token(refresh_token)
      user = record&.subject
      raise ApiError.new(:invalid_token) unless user.is_a?(User) && user.account_id == @account.id

      outcome = RefreshToken.transaction do
        record.lock!
        rejection = rejection_for(record, user)
        next rejection if rejection

        record.mark_used!
        TokenIssuer.new(account: @account).issue(
          user: user,
          authenticated_at: record.authenticated_at,
          amr: record.amr,
          family_id: record.family_id,
          refresh_expires_at: record.expires_at
        )
      end

      raise ApiError.new(outcome) if outcome.is_a?(Symbol)

      outcome
    end

    private

    def rejection_for(record, user)
      if record.used?
        RefreshToken.revoke_family!(record.family_id)
        AuditEvents::Recorder.new(account: @account).record(action: "user.refresh_token_reused", actor: user, target: user)
        return :invalid_token
      end

      return :invalid_token if record.revoked? || !user.active?
      return :session_expired if record.expired?

      if idle?(record) || (@configuration.mfa_required? && !record.amr.include?("otp"))
        RefreshToken.revoke_family!(record.family_id)
        return idle?(record) ? :session_expired : :mfa_required
      end

      nil
    end

    def idle?(record)
      timeout = @configuration.session_idle_timeout
      timeout.present? && record.created_at < timeout.ago
    end
  end
end
