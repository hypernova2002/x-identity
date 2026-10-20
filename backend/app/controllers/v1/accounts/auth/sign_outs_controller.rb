module V1
  module Accounts
    module Auth
      class SignOutsController < BaseController
        def create
          ::Auth::SignOut.new(account: current_account).call(**RefreshTokenRequest.from_params(params).to_h)
          head :no_content
        end
      end
    end
  end
end
