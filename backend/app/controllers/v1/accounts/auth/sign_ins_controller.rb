module V1
  module Accounts
    module Auth
      class SignInsController < BaseController
        def create
          result = ::Auth::SignIn.new(account: current_account).call(**SignInRequest.from_params(params).to_h)
          render json: SignInResultSerializer.new(result).serializable_hash
        end
      end
    end
  end
end
