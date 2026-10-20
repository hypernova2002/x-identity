# Account owners and admins can do anything with every project. Other users see only projects
# they're a member of, and only project admins can change them.
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

  def update?
    same_account? && (@user.account_admin? || membership&.admin? || false)
  end

  def manage_members?
    update?
  end

  def destroy?
    same_account? && @user.account_admin?
  end

  private

  def same_account?
    @user.account_id == @project.account_id
  end

  def membership
    return @membership if defined?(@membership)

    @membership = @project.project_memberships.find_by(user: @user)
  end
end
