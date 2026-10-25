module V1
  module Accounts
    module Projects
      module Me
        # The end user's own passkeys, which belong to the project's custom domain. They can be added
        # on the domain, or from the allowed origins of the app the access token was issued to.
        class PasskeysController < EndUserController
          include OwnPasskeys

          private

          def relying_party
            ::Passkeys::RelyingParties.for(current_user, endpoints: current_endpoints, app_client: token_app_client)
          end
        end
      end
    end
  end
end
