module V1
  module Accounts
    module Projects
      # A confidential client's secrets: which work, when each was last used, and revoking old ones.
      class AppClientSecretsController < ManagementController
        before_action :set_app_client

        def index
          render json: AppClientSecretSerializer.new(@app_client.secrets.order(created_at: :desc, id: :desc)).serializable_hash
        end

        def destroy
          ::AppClients::Management.new(actor: current_user, project: current_project, **client_info)
            .revoke_secret(@app_client, @app_client.secrets.find_by_uid!(params[:uid]))
          head :no_content
        end

        private

        def set_app_client
          @app_client = current_project.app_clients.managed.find_by_uid!(params[:app_client_uid])
        end
      end
    end
  end
end
