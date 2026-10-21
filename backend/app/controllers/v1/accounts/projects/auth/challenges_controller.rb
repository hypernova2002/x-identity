module V1
  module Accounts
    module Projects
      module Auth
        class ChallengesController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::ChallengeResponseRequest)
            result = ::Auth::ChallengeResponse.new(realm: realm, app_client: app_client, **client_info).call(**input)
            render json: SignInResultSerializer.new(result).serializable_hash
          end
        end
      end
    end
  end
end
