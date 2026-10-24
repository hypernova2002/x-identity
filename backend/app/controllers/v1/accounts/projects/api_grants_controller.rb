module V1
  module Accounts
    module Projects
      # The APIs a machine-to-machine app may get tokens for, and with which scopes.
      class ApiGrantsController < ManagementController
        before_action :set_app_client
        before_action :set_grant, only: %i[update destroy]

        def index
          render json: ApiGrantSerializer.new(@app_client.api_grants.includes(:api_resource).order(:created_at, :id)).serializable_hash
        end

        def create
          input = parse_request(::ApiGrants::CreateRequest).to_h
          api = current_project.api_resources.find_by_uid!(input[:api_uid])
          render json: ApiGrantSerializer.new(management.grant(@app_client, api, scopes: input[:scopes])).serializable_hash, status: :created
        end

        def update
          grant = management.update_grant(@grant, **parse_request(::ApiGrants::UpdateRequest).to_h)
          render json: ApiGrantSerializer.new(grant).serializable_hash
        end

        def destroy
          management.revoke_grant(@grant)
          head :no_content
        end

        private

        def set_app_client
          @app_client = current_project.app_clients.managed.find_by_uid!(params[:app_client_uid])
        end

        def set_grant
          @grant = @app_client.api_grants.find_by_uid!(params[:uid])
        end

        def management
          ::ApiResources::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
