module Accounts
  class AuthConfigurationUpdate
    # @param actor [User]
    def initialize(actor:)
      @actor = actor
      @configuration = actor.account.auth_configuration!
    end

    # @param attributes [Hash] permitted {AuthConfiguration} attributes
    # @return [AuthConfiguration]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def call(attributes)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@actor).manage?

      @configuration.assign_attributes(attributes)
      changes = @configuration.changes.transform_values { |from, to| { from: from, to: to } }
      raise ApiError.from_record(@configuration) unless @configuration.save

      if changes.any?
        AuditEvents::Recorder.new(account: @actor.account).record(
          action: "account.auth_configuration_updated", actor: @actor, target: @actor.account, metadata: { changes: changes }
        )
      end
      @configuration
    end
  end
end
