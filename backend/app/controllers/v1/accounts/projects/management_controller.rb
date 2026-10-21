module V1
  module Accounts
    module Projects
      # Console endpoints for managing a project. Projects the console user can't view are 404s.
      class ManagementController < Accounts::AuthenticatedController
        include Paginated

        before_action :set_project

        private

        def set_project
          @project = current_account.projects.find_by_uid!(params[:project_uid])
          raise ActiveRecord::RecordNotFound unless ProjectPolicy.new(current_user, @project).view?
        end

        def current_project
          @project
        end

        # @param permission [Symbol] a {ProjectPolicy} predicate, e.g. `:manage_end_users?`
        # @raise [ApiError] `forbidden`
        def authorize_project!(permission)
          raise ApiError.new(:forbidden) unless ProjectPolicy.new(current_user, current_project).public_send(permission)
        end
      end
    end
  end
end
