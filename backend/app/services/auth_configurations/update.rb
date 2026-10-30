module AuthConfigurations
  # Updates the auth configuration of an account (console users) or a project (end users).
  class Update
    # @param actor [User]
    # @param owner [Account, Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, owner:, ip: nil, user_agent: nil)
      @actor = actor
      @owner = owner
      @ip = ip
      @user_agent = user_agent
    end

    # @param attributes [Hash] {AuthConfiguration} settings to change
    # @return [AuthConfiguration]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def call(attributes)
      raise ApiError.new(:forbidden) unless allowed?

      configuration = @owner.auth_configuration!
      changes = configuration.with_lock do
        configuration.assign_attributes(attributes)
        changed = configuration.changes.transform_values { |from, to| { from: from, to: to } }
        raise ApiError.from_record(configuration) unless configuration.save

        changed
      end

      if changes.any?
        @owner.realm.recorder(ip: @ip, user_agent: @user_agent).record(
          action: "#{@owner.model_name.element}.auth_configuration_updated", actor: @actor, target: @owner, metadata: { changes: changes }
        )
      end
      configuration
    end

    private

    def allowed?
      case @owner
      when Account then @actor.account_id == @owner.id && AccountPolicy.new(@actor).manage?
      when Project then ProjectPolicy.new(@actor, @owner).manage_settings?
      else false
      end
    end
  end
end
