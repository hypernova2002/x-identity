module V1
  module Accounts
    module Projects
      class AttributeDefinitionsController < ManagementController
        before_action :set_definition, only: %i[update destroy]

        def index
          definitions = paginated(current_project.end_user_attribute_definitions.order(:created_at, :id))
          render json: AttributeDefinitionSerializer.new(definitions).serializable_hash
        end

        def create
          definition = management.create(**parse_request(::AttributeDefinitions::CreateRequest).to_h)
          render json: AttributeDefinitionSerializer.new(definition).serializable_hash, status: :created
        end

        def update
          definition = management.update(@definition, **parse_request(::AttributeDefinitions::UpdateRequest).to_h)
          render json: AttributeDefinitionSerializer.new(definition).serializable_hash
        end

        def destroy
          management.destroy(@definition)
          head :no_content
        end

        private

        def set_definition
          @definition = current_project.end_user_attribute_definitions.find_by_uid!(params[:uid])
        end

        def management
          ::AttributeDefinitions::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
