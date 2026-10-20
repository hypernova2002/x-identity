module Projects
  class Management
    # @param actor [User]
    def initialize(actor:)
      @actor = actor
      @account = actor.account
    end

    # @param name [String]
    # @return [Project]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(name:)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@actor).manage?

      project = @account.projects.new(name: name)
      raise ApiError.from_record(project) unless project.save

      recorder.record(action: "project.created", actor: @actor, target: project, project: project)
      project
    end

    # @param project [Project]
    # @param name [String]
    # @return [Project]
    def update(project, name:)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).update?

      previous_name = project.name
      raise ApiError.from_record(project) unless project.update(name: name)

      recorder.record(action: "project.updated", actor: @actor, target: project, project: project, metadata: { from: previous_name, to: project.name })
      project
    end

    # @param project [Project]
    def destroy(project)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).destroy?

      project.destroy!
      recorder.record(action: "project.deleted", actor: @actor, target: project)
    end

    private

    def recorder
      AuditEvents::Recorder.new(account: @account)
    end
  end
end
