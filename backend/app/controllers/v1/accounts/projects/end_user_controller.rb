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

        # @return [AppClient, nil] the app the access token was issued to (its audience)
        def token_app_client
          current_project.app_clients.enabled.find_by(uid: @access_token_claims["aud"])
        end
      end
    end
  end
end
