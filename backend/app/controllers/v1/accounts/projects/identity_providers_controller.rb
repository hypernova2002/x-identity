module V1
  module Accounts
    module Projects
      class IdentityProvidersController < ManagementController
        LIST = ListQuery.new(
          search: "name_i_cont",
          filters: %i[kind_eq kind_in enabled_eq],
          sorts: { "name" => :name, "kind" => :kind, "created_at" => :created_at },
          default_sort: "created_at"
        )

        before_action :set_identity_provider, only: %i[show update destroy]

        def index
          providers = listed(current_project.identity_providers.includes(project: :account), LIST)
          render json: IdentityProviderSerializer.new(providers).serializable_hash
        end

        def show
          render json: IdentityProviderSerializer.new(@identity_provider).serializable_hash
        end

        def create
          provider = management.create(**parse_request(::IdentityProviders::CreateRequest).to_h)
          render json: IdentityProviderSerializer.new(provider).serializable_hash, status: :created
        end

        def update
          provider = management.update(@identity_provider, **parse_request(::IdentityProviders::UpdateRequest).to_h)
          render json: IdentityProviderSerializer.new(provider).serializable_hash
        end

        def parse_saml_metadata
          render json: management.parse_saml_metadata(**parse_request(::IdentityProviders::ParseSamlMetadataRequest).to_h)
        end

        def destroy
          management.destroy(@identity_provider)
          head :no_content
        end

        private

        def set_identity_provider
          @identity_provider = current_project.identity_providers.find_by_uid!(params[:uid])
        end

        def management
          ::IdentityProviders::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
