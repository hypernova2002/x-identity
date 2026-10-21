module V1
  module Accounts
    module Projects
      class AppClientsController < ManagementController
        before_action :set_app_client, only: %i[show update destroy rotate_secret]

        def index
          app_clients = paginated(current_project.app_clients.order(:created_at, :id))
          render json: AppClientSerializer.new(app_clients).serializable_hash
        end

        def show
          render json: AppClientSerializer.new(@app_client).serializable_hash
        end

        def create
          created = management.create(**parse_request(::AppClients::CreateRequest).to_h)
          render json: AppClientWithSecretSerializer.new(created).serializable_hash, status: :created
        end

        def update
          app_client = management.update(@app_client, **parse_request(::AppClients::UpdateRequest).to_h)
          render json: AppClientSerializer.new(app_client).serializable_hash
        end

        def rotate_secret
          render json: AppClientWithSecretSerializer.new(management.rotate_secret(@app_client)).serializable_hash
        end

        def destroy
          management.destroy(@app_client)
          head :no_content
        end

        private

        def set_app_client
          @app_client = current_project.app_clients.find_by_uid!(params[:uid])
        end

        def management
          ::AppClients::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
