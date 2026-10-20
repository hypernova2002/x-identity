module Users
  # Account-level changes an admin makes to other users. Protects the account from losing its
  # last active owner.
  class Management
    # @param actor [User]
    def initialize(actor:)
      @actor = actor
      @account = actor.account
    end

    # @param target [User]
    # @param role [String, nil]
    # @param status [String, nil] "active" or "disabled"
    # @return [User]
    # @raise [ApiError] `forbidden`, `last_owner` or `validation_failed`
    def update(target, role: nil, status: nil)
      raise ApiError.new(:forbidden) unless UserManagementPolicy.new(@actor, target).update?(role: role)
      raise ApiError.validation(role: "is not included in the list") if role && !User.roles.key?(role.to_s)
      raise ApiError.validation(status: "is not included in the list") if status && !User.statuses.key?(status.to_s)

      previous_role = target.role
      previous_status = target.status

      User.transaction do
        @account.lock!
        losing_owner = target.owner? && ((role && role.to_s != "owner") || status.to_s == "disabled")
        ensure_another_owner!(target) if losing_owner

        target.update!(role: role) if role
        target.disable! if status.to_s == "disabled" && target.active?
        target.enable! if status.to_s == "active" && target.disabled?
      end

      record_changes(target, previous_role, previous_status)
      target
    end

    # @param target [User]
    # @raise [ApiError] `forbidden` or `last_owner`
    def destroy(target)
      raise ApiError.new(:forbidden) unless UserManagementPolicy.new(@actor, target).destroy?

      User.transaction do
        @account.lock!
        ensure_another_owner!(target) if target.owner?
        target.destroy!
      end

      recorder.record(action: "user.deleted", actor: @actor, target: target)
    end

    private

    def ensure_another_owner!(target)
      return if @account.users.owner.active.where.not(id: target.id).exists?

      raise ApiError.new(:last_owner)
    end

    def record_changes(target, previous_role, previous_status)
      if target.role != previous_role
        recorder.record(action: "user.role_changed", actor: @actor, target: target, metadata: { from: previous_role, to: target.role })
      end
      return if target.status == previous_status

      recorder.record(action: target.disabled? ? "user.disabled" : "user.enabled", actor: @actor, target: target)
    end

    def recorder
      AuditEvents::Recorder.new(account: @account)
    end
  end
end
