module V1
  module Accounts
    class AuditEventsController < AuthenticatedController
      include Paginated

      FILTERS = %i[action_eq action_start actor_uid_eq target_uid_eq project_uid_eq occurred_at_gteq occurred_at_lteq].freeze

      before_action :require_account_admin!

      def index
        events = current_account.audit_events.ransack(params.fetch(:q, {}).permit(*FILTERS)).result
        events = paginated(events.includes(:project).order(occurred_at: :desc, id: :desc))
        render json: AuditEventSerializer.new(events).serializable_hash
      end
    end
  end
end
