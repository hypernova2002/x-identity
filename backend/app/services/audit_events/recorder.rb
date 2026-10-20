module AuditEvents
  class Recorder
    # @param account [Account]
    # @param request_context [RequestContext]
    def initialize(account:, request_context: Current.request_context || RequestContext.blank)
      @account = account
      @request_context = request_context
    end

    # @param action [String] dotted event name, e.g. `user.signed_in`
    # @param actor [User, nil] who did it; nil for unauthenticated requests
    # @param target [ApplicationRecord, nil] what it was done to
    # @param project [Project, nil]
    # @param metadata [Hash]
    # @return [AuditEvent]
    def record(action:, actor: nil, target: nil, project: nil, metadata: {})
      AuditEvent.create!(
        account: @account,
        project: project,
        action: action,
        actor_type: actor ? actor.class.name.underscore : "anonymous",
        actor_uid: actor&.uid,
        actor_label: label_for(actor),
        target_type: target&.class&.name&.underscore,
        target_uid: target.try(:uid),
        target_label: label_for(target),
        ip: @request_context.ip,
        user_agent: @request_context.user_agent&.truncate(255),
        metadata: metadata,
        occurred_at: Time.current
      )
    end

    private

    def label_for(record)
      record.try(:email) || record.try(:name)
    end
  end
end
