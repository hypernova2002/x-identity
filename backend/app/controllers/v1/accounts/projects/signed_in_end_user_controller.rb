module V1
  module Accounts
    module Projects
      # A signed-in end user's own endpoints (/me, the portal's apps, userinfo), authenticated with an
      # access token from the project. Not to be confused with the console's {EndUsersController}.
      class SignedInEndUserController < PublicController
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
