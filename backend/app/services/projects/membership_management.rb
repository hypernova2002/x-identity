module Projects
  class MembershipManagement
    # @param actor [User]
    # @param project [Project]
    def initialize(actor:, project:)
      @actor = actor
      @project = project
    end

    # @param user_uid [String] a user in the project's account
    # @param role [String]
    # @return [ProjectMembership]
    # @raise [ApiError] `forbidden`, `conflict` or `validation_failed`
    def add(user_uid:, role:)
      authorize!
      user = @project.account.users.find_by(uid: user_uid)
      raise ApiError.validation(user_uid: "does not match a user in this account") if user.nil?
      raise ApiError.new(:conflict, message: "This user is already a member of the project.") if @project.project_memberships.exists?(user: user)

      membership = @project.project_memberships.new(user: user, role: role)
      raise ApiError.from_record(membership) unless membership.save

      recorder.record(action: "project.member_added", actor: @actor, target: user, project: @project, metadata: { role: role })
      membership
    end

    # @param membership [ProjectMembership]
    # @param role [String]
    # @return [ProjectMembership]
    def update(membership, role:)
      authorize!
      previous_role = membership.role
      raise ApiError.from_record(membership) unless membership.update(role: role)

      recorder.record(
        action: "project.member_role_changed", actor: @actor, target: membership.user, project: @project,
        metadata: { from: previous_role, to: membership.role }
      )
      membership
    end

    # @param membership [ProjectMembership]
    def remove(membership)
      authorize!
      membership.destroy!
      recorder.record(action: "project.member_removed", actor: @actor, target: membership.user, project: @project)
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_members?
    end

    def recorder
      AuditEvents::Recorder.new(account: @project.account)
    end
  end
end
