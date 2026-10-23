module Apps
  # Which apps an end user can sign in to, and why: assigned directly, through groups, or both.
  class UserAccess
    # @param end_user [EndUser]
    def initialize(end_user)
      @end_user = end_user
      @project = end_user.project
    end

    # @return [Array<Hash>] one entry per app the user can use, with the assignments that grant it
    def call
      groups = @end_user.groups.to_a.index_by(&:id)
      assignments = AppAssignment.where(project: @project, principal: @end_user)
        .or(AppAssignment.where(project: @project, principal_type: "Group", principal_id: groups.keys))
        .includes(:app).to_a
      apps = assignments.group_by(&:app).reject { |app, _| app.is_a?(AppClient) && app.portal? }

      apps.map do |app, granting|
        {
          app_type: app.is_a?(SamlApp) ? "saml_app" : "app_client",
          uid: app.uid,
          name: app.name,
          enabled: app.enabled,
          via: granting.map { |assignment| via(assignment, groups) }
        }
      end.sort_by { |entry| [ entry[:name].downcase, entry[:uid] ] }
    end

    private

    def via(assignment, groups)
      return { type: "direct", assignment_uid: assignment.uid } if assignment.principal_type == "EndUser"

      group = groups.fetch(assignment.principal_id)
      { type: "group", assignment_uid: assignment.uid, group_uid: group.uid, group_name: group.name }
    end
  end
end
