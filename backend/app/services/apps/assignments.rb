module Apps
  # Giving end users and groups access to an app client or SAML app, and taking it away.
  class Assignments
    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, project:, ip: nil, user_agent: nil)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param app [AppClient, SamlApp]
    # @param principal [EndUser, Group]
    # @return [AppAssignment]
    # @raise [ApiError] `forbidden` or `conflict`
    def assign(app, principal)
      authorize!
      raise ApiError.new(:conflict, message: "#{label(principal)} already has access to #{app.name}.") if AppAssignment.exists?(app: app, principal: principal)

      assignment = AppAssignment.create!(project: @project, app: app, principal: principal)
      record("app.assigned", app, assignment)
      assignment
    end

    # People who lose access are refused at their next sign-in or token refresh.
    # @param assignment [AppAssignment]
    def unassign(assignment)
      authorize!
      assignment.destroy!
      record("app.unassigned", assignment.app, assignment)
    end

    private

    def label(principal)
      principal.is_a?(Group) ? principal.name : principal.email
    end

    def record(action, app, assignment)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent).record(
        action: action, actor: @actor, target: app,
        metadata: { principal_type: assignment.principal_type.underscore, principal: assignment.principal.uid, label: label(assignment.principal) }
      )
    end

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_app_clients?
    end
  end
end
