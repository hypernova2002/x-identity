module V1
  module Accounts
    module Projects
      # An end user's signed-in devices, for project admins and developers.
      class EndUserSessionsController < ConsoleController
        include DeviceSessionListing

        before_action -> { authorize_project!(:manage_end_users?) }, only: :index
        before_action :set_end_user

        def index
          render_device_sessions(@end_user)
        end

        def destroy
          ::EndUsers::Management.new(actor: current_user, project: current_project, **client_info)
            .sign_out_device(@end_user.device_sessions.find_by_uid!(params[:uid]))
          head :no_content
        end

        private

        def set_end_user
          @end_user = current_project.end_users.find_by_uid!(params[:end_user_uid])
        end
      end
    end
  end
end
