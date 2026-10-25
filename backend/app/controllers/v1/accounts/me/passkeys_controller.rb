module V1
  module Accounts
    module Me
      # The console user's own passkeys, which belong to the console's host.
      class PasskeysController < AuthenticatedController
        include OwnPasskeys

        private

        def relying_party
          ::Passkeys::RelyingParties.for(current_user)
        end
      end
    end
  end
end
