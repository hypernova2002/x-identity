module V1
  module Accounts
    module Projects
      # App clients (including machine-to-machine apps) and SAML apps in one list. Each kind is managed through its own endpoints.
      class ApplicationsController < ManagementController
        def index
          render json: ApplicationSerializer.new(paginated(::Apps::Directory.new(current_project, params))).serializable_hash
        end
      end
    end
  end
end
