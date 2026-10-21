module V1
  module Accounts
    module Projects
      class AuditEventsController < ManagementController
        include AuditLogListing

        before_action { authorize_project!(:view_audit_log?) }

        def index
          render_audit_events(current_project.realm.account.audit_events.where(project_id: current_project.id))
        end
      end
    end
  end
end
