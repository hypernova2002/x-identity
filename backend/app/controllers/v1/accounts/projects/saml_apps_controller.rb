module V1
  module Accounts
    module Projects
      class SamlAppsController < ConsoleController
        before_action :set_saml_app, only: %i[show update destroy]

        def index
          render json: SamlAppSerializer.new(paginated(current_project.saml_apps.order(:name, :id))).serializable_hash
        end

        def show
          render json: SamlAppSerializer.new(@saml_app).serializable_hash
        end

        def create
          app = management.create(**parse_request(::SamlApps::CreateRequest).to_h)
          render json: SamlAppSerializer.new(app).serializable_hash, status: :created
        end

        def update
          app = management.update(@saml_app, **parse_request(::SamlApps::UpdateRequest).to_h)
          render json: SamlAppSerializer.new(app).serializable_hash
        end

        def destroy
          management.destroy(@saml_app)
          head :no_content
        end

        def parse_metadata
          render json: management.parse_metadata(**parse_request(::SamlApps::ParseMetadataRequest).to_h)
        end

        private

        def set_saml_app
          @saml_app = current_project.saml_apps.find_by_uid!(params[:uid])
        end

        def management
          ::SamlApps::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
