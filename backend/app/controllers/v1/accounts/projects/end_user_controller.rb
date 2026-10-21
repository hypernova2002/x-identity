module V1
  module Accounts
    module Projects
      # Endpoints for a signed-in end user, authenticated with an access token from the project.
      class EndUserController < BaseController
        include Authentication

        private

        def token_realm
          current_project.realm
        end
      end
    end
  end
end
