module V1
  module Accounts
    module Projects
      module Auth
        class MfaSetupsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::MfaSetupRequest)
            enrollment = ::Auth::ChallengeResponse.new(realm: realm, app_client: app_client, **client_info)
              .start_mfa_setup(**input)
            render json: MfaEnrollmentSerializer.new(enrollment).serializable_hash
          end
        end
      end
    end
  end
end
