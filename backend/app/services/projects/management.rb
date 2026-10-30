module Projects
  # Creating and deleting projects are account-level events; changes to a project's own settings
  # go to the project's audit log.
  class Management
    SETTINGS = %i[name allow_self_sign_up confirm_sign_up_url reset_password_url accept_invitation_url].freeze

    # @param actor [User]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, ip: nil, user_agent: nil)
      @actor = actor
      @account = actor.account
      @ip = ip
      @user_agent = user_agent
    end

    # @param name [String]
    # @return [Project]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(name:)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@actor).manage?

      project = @account.projects.new(name: name)
      Project.transaction do
        raise ApiError.from_record(project) unless project.save

        project.auth_configuration!
        @account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "project.created", actor: @actor, target: project)
      end

      project
    end

    # @param project [Project]
    # @param attributes [Hash] any of {SETTINGS}
    # @return [Project]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def update(project, **attributes)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).update?

      project.assign_attributes(attributes.slice(*SETTINGS))
      changes = project.changes.transform_values { |from, to| { from: from, to: to } }
      Project.transaction do
        raise ApiError.from_record(project) unless project.save

        if changes.any?
          project.realm.recorder(ip: @ip, user_agent: @user_agent)
            .record(action: "project.updated", actor: @actor, target: project, metadata: { changes: changes })
        end
      end
      project
    end

    # Deletes the project at once: it disappears from every list and endpoint, and nobody can sign
    # in to it. Its data is purged after {Project::RESTORE_PERIOD}, until when it can be restored.
    # @param project [Project]
    # @raise [ApiError] `forbidden`
    def destroy(project)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).destroy?

      Project.transaction do
        project.update!(deleted_at: Time.current)
        record("project.deleted", project, purge_at: project.purge_at.iso8601)
      end
      ProjectPurgeJob.set(wait_until: project.purge_at).perform_later(project_id: project.id)
    end

    # Brings back a deleted project that hasn't been purged yet.
    # @param project [Project] one of the account's deleted projects
    # @raise [ApiError] `forbidden`
    def restore(project)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@actor).manage?

      Project.transaction do
        project.update!(deleted_at: nil)
        record("project.restored", project)
      end
    end

    private

    def record(action, project, **metadata)
      @account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: action, actor: @actor, target: project, metadata: metadata)
    end
  end
end
