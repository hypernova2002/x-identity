module V1
  module Accounts
    module Projects
      # The project's custom domain, and its replacement while one is being set up (at most two).
      class DomainsController < ConsoleController
        before_action :set_domain, only: %i[check destroy]

        def index
          render json: ProjectDomainSerializer.new(current_project.domains.order(:created_at, :id)).serializable_hash
        end

        def create
          domain = management.add(**parse_request(::Domains::CreateRequest).to_h)
          render json: ProjectDomainSerializer.new(domain).serializable_hash, status: :created
        end

        def check
          render json: ProjectDomainSerializer.new(management.check(@domain)).serializable_hash
        end

        def destroy
          management.remove(@domain)
          head :no_content
        end

        private

        def set_domain
          @domain = current_project.domains.find_by_uid!(params[:uid])
        end

        def management
          ::Domains::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
