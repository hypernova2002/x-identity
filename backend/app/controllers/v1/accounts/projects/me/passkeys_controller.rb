module V1
  module Accounts
    module Projects
      module Me
        # The end user's own passkeys, which belong to the project's custom domain.
        class PasskeysController < EndUserController
          include OwnPasskeys

          private

          def relying_party
            ::Passkeys::RelyingParties.for(current_user, endpoints: current_endpoints)
          end
        end
      end
    end
  end
end
