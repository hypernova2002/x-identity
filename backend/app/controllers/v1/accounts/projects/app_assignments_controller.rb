module V1
  module Accounts
    module Projects
      # Who can use an app client or SAML app. The route says which kind of app.
      class AppAssignmentsController < ManagementController
        before_action :set_app

        def index
          assignments = paginated(@app.app_assignments.includes(:principal).order(:created_at, :id))
          render json: AppAssignmentSerializer.new(assignments).serializable_hash
        end

        def create
          input = parse_request(::AppAssignments::CreateRequest)
          principals = input.principal_type == "group" ? current_project.groups : current_project.end_users
          assignment = assignments.assign(@app, principals.find_by_uid!(input.principal_uid))
          render json: AppAssignmentSerializer.new(assignment).serializable_hash, status: :created
        end

        def destroy
          assignments.unassign(@app.app_assignments.find_by_uid!(params[:uid]))
          head :no_content
        end

        private

        def set_app
          @app = if params[:app_kind] == "saml_app"
            current_project.saml_apps.find_by_uid!(params[:saml_app_uid])
          else
            current_project.app_clients.managed.find_by_uid!(params[:app_client_uid])
          end
        end

        def assignments
          ::Apps::Assignments.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
