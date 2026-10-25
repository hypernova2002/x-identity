module V1
  module Accounts
    module Auth
      class MfaSetupsController < BaseController
        def create
          enrollment = ::Auth::ChallengeResponse.new(context: ::Auth::SignInContext.new(realm: current_account.realm, **client_info))
            .start_mfa_setup(**parse_request(::Auth::MfaSetupRequest).to_h)
          render json: MfaEnrollmentSerializer.new(enrollment).serializable_hash
        end
      end
    end
  end
end
