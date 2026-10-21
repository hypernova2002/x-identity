# Filtering and pagination shared by the account and project audit logs.
module AuditLogListing
  FILTERS = %i[action_eq action_start actor_uid_eq target_uid_eq app_client_uid_eq occurred_at_gteq occurred_at_lteq].freeze

  private

  # @param scope [ActiveRecord::Relation<AuditEvent>]
  def render_audit_events(scope)
    events = scope.ransack(params.fetch(:q, {}).permit(*FILTERS)).result
    events = paginated(events.includes(:project).order(occurred_at: :desc, id: :desc))
    render json: AuditEventSerializer.new(events).serializable_hash
  end
end
