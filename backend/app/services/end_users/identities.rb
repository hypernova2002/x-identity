module EndUsers
  # Removing an end user's link to an identity provider, by the user themselves or an admin.
  class Identities
    # @param end_user [EndUser]
    # @param actor [User, EndUser] who is unlinking
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(end_user:, actor:, ip: nil, user_agent: nil)
      @end_user = end_user
      @actor = actor
      @ip = ip
      @user_agent = user_agent
    end

    # @param identity [EndUserIdentity]
    # @raise [ApiError] `last_sign_in_method` when the user has no password and no other identity
    def unlink(identity)
      EndUserIdentity.transaction do
        @end_user.lock!
        raise ApiError.new(:last_sign_in_method) if !@end_user.password_set? && @end_user.identities.where.not(id: identity.id).none?

        identity.destroy!
      end

      @end_user.project.realm.recorder(ip: @ip, user_agent: @user_agent).record(
        action: "end_user.identity_unlinked", actor: @actor, target: @end_user,
        metadata: { identity: identity.uid, identity_provider: identity.identity_provider.uid }
      )
    end
  end
end
