module V1
  module Accounts
    module Projects
      # Tells hosted pages served on a custom domain which project they belong to.
      class HostedDomainsController < BaseController
        def show
          render json: {
            account_uid: current_account.uid, account_slug: current_account.slug, account_name: current_account.name,
            project_uid: current_project.uid, project_name: current_project.name,
            issuer: current_endpoints.issuer
          }
        end
      end
    end
  end
end
