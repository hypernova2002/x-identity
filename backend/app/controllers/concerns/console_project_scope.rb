# Finds a project of the current account for a console user. Projects they can't view are reported
# as missing, so their existence isn't revealed.
module ConsoleProjectScope
  private

  # @param uid [String]
  # @return [Project]
  # @raise [ActiveRecord::RecordNotFound]
  def find_viewable_project!(uid)
    project = current_account.projects.find_by_uid!(uid)
    raise ActiveRecord::RecordNotFound unless ProjectPolicy.new(current_user, project).view?

    project
  end
end
