# Search, filtering, sorting and pagination shared by the account and project audit logs.
module AuditLogListing
  include Listing

  LIST = ListQuery.new(
    search: "action_start",
    filters: %i[action_eq action_start actor_uid_eq target_uid_eq app_client_uid_eq occurred_at_gteq occurred_at_lteq],
    sorts: { "occurred_at" => :occurred_at },
    default_sort: "-occurred_at"
  )

  private

  # @param scope [ActiveRecord::Relation<AuditEvent>]
  def render_audit_events(scope)
    events = listed(scope.includes(:project), LIST)
    render json: AuditEventSerializer.new(events).serializable_hash
  end
end
