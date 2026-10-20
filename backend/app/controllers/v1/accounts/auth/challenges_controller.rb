module V1
  module Accounts
    module Auth
      class ChallengesController < BaseController
        def create
          result = ::Auth::ChallengeResponse.new(account: current_account).call(**ChallengeResponseRequest.from_params(params).to_h)
          render json: SignInResultSerializer.new(result).serializable_hash
        end
      end
    end
  end
end
