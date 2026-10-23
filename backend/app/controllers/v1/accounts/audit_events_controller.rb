module V1
  module Accounts
    # The account's own audit log. Events inside a project are in that project's log.
    class AuditEventsController < AuthenticatedController
      include AuditLogListing

      before_action :require_account_admin!

      def index
        render_audit_events(current_account.audit_events.where(project_id: nil))
      end
    end
  end
end
