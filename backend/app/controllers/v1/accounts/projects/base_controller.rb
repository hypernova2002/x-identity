module V1
  module Accounts
    module Projects
      # Loads the project from the URL, or from the custom domain the request arrived on. Unknown
      # projects, and projects of other accounts, are 404s.
      class BaseController < Accounts::BaseController
        before_action :set_project

        private

        def set_project
          @project = custom_domain ? custom_domain.project : current_account.projects.find_by_uid!(params[:project_uid])
        end

        def current_project
          @project
        end

        # @return [ProjectEndpoints] the URLs this request is served on, which the flows it starts keep using
        def current_endpoints
          @current_endpoints ||= ProjectEndpoints.new(current_project, domain: custom_domain)
        end
      end
    end
  end
end
