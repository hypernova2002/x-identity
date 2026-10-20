module V1
  module Accounts
    module Auth
      class RefreshesController < BaseController
        def create
          tokens = ::Auth::Refresh.new(account: current_account).call(**RefreshTokenRequest.from_params(params).to_h)
          render json: TokenSetSerializer.new(tokens).serializable_hash
        end
      end
    end
  end
end
