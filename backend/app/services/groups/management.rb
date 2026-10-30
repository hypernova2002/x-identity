module Groups
  class Management
    EDITABLE = %i[name description default_for_new_users].freeze

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

    # @param attributes [Hash] name, and optionally description and default_for_new_users
    # @return [Group]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(**attributes)
      authorize!
      group = @project.groups.new(attributes.slice(*EDITABLE))
      Group.transaction do
        raise ApiError.from_record(group) unless group.save

        recorder.record(action: "group.created", actor: @actor, target: group)
      end
      group
    end

    # @param group [Group]
    # @param changes [Hash] any of {EDITABLE}
    # @return [Group]
    def update(group, **changes)
      authorize!
      group.assign_attributes(changes.slice(*EDITABLE))
      changed = group.changes.transform_values { |from, to| { from: from, to: to } }
      Group.transaction do
        raise ApiError.from_record(group) unless group.save

        recorder.record(action: "group.updated", actor: @actor, target: group, metadata: { changes: changed }) if changed.any?
      end
      group
    end

    # Members lose access to the apps assigned to the group.
    # @param group [Group]
    def destroy(group)
      authorize!
      Group.transaction do
        group.destroy!
        recorder.record(action: "group.deleted", actor: @actor, target: group)
      end
    end

    # @param group [Group]
    # @param end_user [EndUser]
    # @raise [ApiError] `conflict` when the user is already a member
    def add_member(group, end_user)
      authorize!
      raise ApiError.new(:conflict, message: "#{end_user.email} is already in #{group.name}.") if group.group_memberships.exists?(end_user: end_user)

      GroupMembership.transaction do
        group.group_memberships.create!(end_user: end_user)
        recorder.record(action: "group.member_added", actor: @actor, target: group, metadata: { end_user: end_user.uid, email: end_user.email })
      end
    end

    # @param group [Group]
    # @param end_user [EndUser]
    def remove_member(group, end_user)
      authorize!
      GroupMembership.transaction do
        group.group_memberships.find_by!(end_user: end_user).destroy!
        recorder.record(action: "group.member_removed", actor: @actor, target: group, metadata: { end_user: end_user.uid, email: end_user.email })
      end
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_end_users?
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
