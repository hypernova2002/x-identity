module V1
  module Accounts
    module Projects
      # An end user's signed-in devices, for project admins and developers.
      class EndUserSessionsController < ManagementController
        include DeviceSessionListing

        before_action -> { authorize_project!(:manage_end_users?) }
        before_action :set_end_user

        def index
          render_device_sessions(@end_user)
        end

        def destroy
          ::DeviceSessions::Management.new(actor: current_user, realm: current_project.realm, **client_info)
            .sign_out(@end_user.device_sessions.find_by_uid!(params[:uid]))
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
