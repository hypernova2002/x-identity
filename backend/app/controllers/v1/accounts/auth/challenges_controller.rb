module V1
  module Accounts
    module Auth
      class ChallengesController < BaseController
        def create
          result = ::Auth::ChallengeResponse.new(context: ::Auth::SignInContext.new(realm: current_account.realm, **client_info))
            .call(**parse_request(::Auth::ChallengeResponseRequest).to_h)
          render json: SignInResultSerializer.new(result).serializable_hash
        end
      end
    end
  end
end
