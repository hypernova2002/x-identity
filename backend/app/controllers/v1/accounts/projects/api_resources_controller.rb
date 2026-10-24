module V1
  module Accounts
    module Projects
      # The project's APIs, for machine-to-machine apps to get tokens for.
      class ApiResourcesController < ManagementController
        LIST = ListQuery.new(
          search: "name_or_identifier_i_cont",
          sorts: { "name" => :name, "identifier" => :identifier, "created_at" => :created_at },
          default_sort: "name"
        )

        before_action :set_api, only: %i[show update destroy]

        def index
          render json: ApiResourceSerializer.new(listed(current_project.api_resources.includes(:api_grants), LIST)).serializable_hash
        end

        def show
          render json: ApiResourceSerializer.new(@api).serializable_hash
        end

        def create
          api = management.create(**parse_request(::ApiResources::CreateRequest).to_h)
          render json: ApiResourceSerializer.new(api).serializable_hash, status: :created
        end

        def update
          api = management.update(@api, **parse_request(::ApiResources::UpdateRequest).to_h)
          render json: ApiResourceSerializer.new(api).serializable_hash
        end

        def destroy
          management.destroy(@api)
          head :no_content
        end

        private

        def set_api
          @api = current_project.api_resources.find_by_uid!(params[:uid])
        end

        def management
          ::ApiResources::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
