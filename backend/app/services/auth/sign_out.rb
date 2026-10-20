module Auth
  class SignOut
    # @param account [Account]
    def initialize(account:)
      @account = account
    end

    # Revokes the refresh token's whole family. Unknown tokens are ignored so sign-out always succeeds.
    # @param refresh_token [String]
    def call(refresh_token:)
      record = RefreshToken.find_by_token(refresh_token)
      user = record&.subject
      return unless user.is_a?(User) && user.account_id == @account.id

      RefreshToken.revoke_family!(record.family_id)
      AuditEvents::Recorder.new(account: @account).record(action: "user.signed_out", actor: user, target: user)
    end
  end
end
