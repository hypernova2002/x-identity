module V1
  module Accounts
    module Auth
      class SignOutsController < BaseController
        def create
          ::Auth::SignOut.new(realm: current_account.realm, **client_info)
            .call(**parse_request(::Auth::SignOutRequest).to_h)
          head :no_content
        end
      end
    end
  end
end
