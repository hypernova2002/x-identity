module V1
  module Accounts
    module Projects
      class AttributeDefinitionsController < ManagementController
        LIST = ListQuery.new(
          search: "key_or_label_i_cont",
          filters: %i[data_type_eq required_eq user_editable_eq include_in_token_eq],
          sorts: { "label" => :label, "key" => :key, "data_type" => :data_type, "created_at" => :created_at },
          default_sort: "created_at"
        )

        before_action :set_definition, only: %i[update destroy]

        def index
          definitions = listed(current_project.end_user_attribute_definitions, LIST)
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
