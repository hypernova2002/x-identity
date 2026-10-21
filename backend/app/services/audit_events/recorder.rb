module AuditEvents
  class Recorder
    # @param account [Account]
    # @param project [Project, nil] scopes events to the project's audit log
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param app_client [AppClient, nil] the app client an end user signed in through
    def initialize(account:, project: nil, ip: nil, user_agent: nil, app_client: nil)
      @account = account
      @project = project
      @ip = ip
      @user_agent = user_agent
      @app_client = app_client
    end

    # @param action [String] dotted event name, e.g. `user.signed_in`
    # @param actor [User, EndUser, nil] who did it; nil for unauthenticated requests
    # @param target [ApplicationRecord, nil] what it was done to
    # @param project [Project, nil] overrides the recorder's project
    # @param metadata [Hash]
    # @return [AuditEvent]
    def record(action:, actor: nil, target: nil, project: @project, metadata: {})
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
        app_client_uid: @app_client&.uid,
        ip: @ip,
        user_agent: @user_agent&.truncate(255),
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
