# What a console user may do at the account level: edit the account and its auth configuration,
# manage users and invitations, create projects and read the audit log.
class AccountPolicy
  # @param user [User]
  def initialize(user)
    @user = user
  end

  def manage?
    @user.account_admin?
  end

  # @param role [String, Symbol] the role being granted
  def grant_role?(role)
    manage? && (@user.owner? || role.to_s != "owner")
  end
end
