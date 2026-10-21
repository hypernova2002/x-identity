module V1
  module Accounts
    module Auth
      class SignInsController < BaseController
        def create
          result = ::Auth::SignIn.new(realm: current_account.realm, **client_info)
            .call(**parse_request(::Auth::SignInRequest).to_h)
          render json: SignInResultSerializer.new(result).serializable_hash
        end
      end
    end
  end
end
