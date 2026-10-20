# Whether one console user may change or remove another. Users manage themselves through /me.
class UserManagementPolicy
  # @param actor [User]
  # @param target [User]
  def initialize(actor, target)
    @actor = actor
    @target = target
  end

  # @param role [String, Symbol, nil] the new role, if changing it
  def update?(role: nil)
    manage_target? && AccountPolicy.new(@actor).grant_role?(role || @target.role)
  end

  def destroy?
    manage_target?
  end

  private

  def manage_target?
    @actor.account_admin? &&
      @actor.account_id == @target.account_id &&
      @actor.id != @target.id &&
      (@actor.owner? || !@target.owner?)
  end
end
