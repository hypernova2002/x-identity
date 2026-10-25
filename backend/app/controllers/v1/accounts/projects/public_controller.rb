module V1
  module Accounts
    module Projects
      # A project's public endpoints (OpenID Connect, SAML, the end-user sign-in API, the portal),
      # served under /v1/accounts/:account_uid/projects/:project_uid and at the root of its custom
      # domain. Loads the project from the URL or the domain; unknown projects, and projects of other
      # accounts, are 404s. The console's endpoints are under {ConsoleController} instead.
      class PublicController < Accounts::BaseController
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
