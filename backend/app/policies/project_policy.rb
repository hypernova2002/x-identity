# Account owners and admins can do anything with every project. Other users see only projects
# they're a member of: project admins manage everything in the project, developers manage its
# app clients and end users, viewers can only look.
class ProjectPolicy
  class Scope
    # @param user [User]
    def initialize(user)
      @user = user
    end

    # @return [ActiveRecord::Relation<Project>]
    def resolve
      projects = @user.account.projects
      return projects if @user.account_admin?

      projects.where(id: @user.project_memberships.select(:project_id))
    end
  end

  # @param user [User]
  # @param project [Project]
  def initialize(user, project)
    @user = user
    @project = project
  end

  def view?
    same_account? && (@user.account_admin? || membership.present?)
  end

  # Rename the project and change its sign-up settings.
  def update?
    admin?
  end

  def manage_members?
    admin?
  end

  def manage_settings?
    admin?
  end

  def manage_end_users?
    admin? || developer?
  end

  def manage_app_clients?
    admin? || developer?
  end

  def manage_attributes?
    admin?
  end

  def view_audit_log?
    admin? || developer?
  end

  def destroy?
    same_account? && @user.account_admin?
  end

  private

  def admin?
    same_account? && (@user.account_admin? || membership&.admin? || false)
  end

  def developer?
    same_account? && (membership&.developer? || false)
  end

  def same_account?
    @user.account_id == @project.account_id
  end

  def membership
    return @membership if defined?(@membership)

    @membership = @project.project_memberships.find_by(user: @user)
  end
end
