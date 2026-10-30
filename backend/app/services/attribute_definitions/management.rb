module AttributeDefinitions
  # Admin-defined end-user attributes. The key and type can't change once created, because stored
  # values depend on them; delete and recreate the attribute instead.
  class Management
    EDITABLE = %i[label required max_length user_editable include_in_token].freeze

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

    # @return [EndUserAttributeDefinition]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(key:, label:, data_type:, **options)
      authorize!
      definition = @project.end_user_attribute_definitions.new(key: key, label: label, data_type: data_type, **options.slice(*EDITABLE))
      EndUserAttributeDefinition.transaction do
        raise ApiError.from_record(definition) unless definition.save

        recorder.record(action: "attribute.created", actor: @actor, target: definition, metadata: { key: key, data_type: data_type })
      end
      definition
    end

    # @param definition [EndUserAttributeDefinition]
    # @return [EndUserAttributeDefinition]
    def update(definition, **changes)
      authorize!
      definition.assign_attributes(changes.slice(*EDITABLE))
      changed = definition.changes.transform_values { |from, to| { from: from, to: to } }
      EndUserAttributeDefinition.transaction do
        raise ApiError.from_record(definition) unless definition.save

        recorder.record(action: "attribute.updated", actor: @actor, target: definition, metadata: { key: definition.key, changes: changed }) if changed.any?
      end
      definition
    end

    # Deletes the attribute and removes its value from every end user in the project.
    # @param definition [EndUserAttributeDefinition]
    def destroy(definition)
      authorize!
      EndUserAttributeDefinition.transaction do
        @project.end_users.where("custom_attributes ? :key", key: definition.key)
          .update_all([ "custom_attributes = custom_attributes - ?", definition.key ])
        definition.destroy!
        recorder.record(action: "attribute.deleted", actor: @actor, target: definition, metadata: { key: definition.key })
      end
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_attributes?
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
