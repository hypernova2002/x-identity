module V1
  module Accounts
    module Projects
      # The console's endpoints for a project, under /v1/accounts/:account_uid/projects/:project_uid,
      # for a signed-in console user. Projects they can't view are 404s.
      #
      # Authorization: viewing the project lets a console user read its settings and lists. Reads that
      # need more (the audit log, an end user's devices) call {#authorize_project!}. Changes are
      # authorized by the service that makes them, which checks {ProjectPolicy}, so every way into a
      # change is covered, not just this controller.
      class ConsoleController < Accounts::AuthenticatedController
        include ConsoleProjectScope
        include Listing

        before_action :set_project

        private

        def set_project
          @project = find_viewable_project!(params[:project_uid])
        end

        def current_project
          @project
        end

        # For reads that need more than viewing the project.
        # @param permission [Symbol] a {ProjectPolicy} predicate, e.g. `:view_audit_log?`
        # @raise [ApiError] `forbidden`
        def authorize_project!(permission)
          raise ApiError.new(:forbidden) unless ProjectPolicy.new(current_user, current_project).public_send(permission)
        end
      end
    end
  end
end
