module V1
  module Accounts
    module Me
      # The console user's signed-in devices.
      class SessionsController < AuthenticatedController
        include DeviceSessionListing

        def index
          render_device_sessions(current_user, current: DeviceSession.for_sid(current_session_id))
        end

        def destroy
          management.sign_out(current_user.device_sessions.find_by_uid!(params[:uid]))
          head :no_content
        end

        def destroy_others
          management.sign_out_others(current_user, keep_session_id: current_session_id)
          head :no_content
        end

        private

        def management
          ::DeviceSessions::Management.new(actor: current_user, realm: current_account.realm, **client_info)
        end
      end
    end
  end
end
