module EndUsers
  # An end user editing their own name and user-editable attributes.
  class Profile
    # @param end_user [EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(end_user:, ip: nil, user_agent: nil)
      @end_user = end_user
      @project = end_user.project
      @ip = ip
      @user_agent = user_agent
    end

    # @param name [String, nil]
    # @param locale [String, nil] see {HasLocale}
    # @param custom_attributes [Hash, nil]
    # @return [EndUser]
    # @raise [ApiError] `validation_failed`
    def update(**changes)
      EndUser.transaction do
        @end_user.lock!
        if changes.key?(:custom_attributes)
          result = AttributeValidator.new(project: @project).validate(changes[:custom_attributes], existing: @end_user.custom_attributes)
          raise ApiError.new(:validation_failed, details: result.details) if result.details.any?

          @end_user.custom_attributes = result.values
        end
        @end_user.name = changes[:name] if changes.key?(:name)
        @end_user.locale = changes[:locale] if changes.key?(:locale)
        raise ApiError.from_record(@end_user) unless @end_user.save

        @project.realm.recorder(ip: @ip, user_agent: @user_agent)
          .record(action: "end_user.profile_updated", actor: @end_user, target: @end_user, metadata: { fields: changes.keys.map(&:to_s) })
      end

      @end_user
    end
  end
end
