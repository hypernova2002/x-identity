module V1
  module Accounts
    module Auth
      class MfaSetupsController < BaseController
        def create
          enrollment = ::Auth::ChallengeResponse.new(account: current_account).start_mfa_setup(**SessionRequest.from_params(params).to_h)
          render json: MfaEnrollmentSerializer.new(enrollment).serializable_hash
        end
      end
    end
  end
end
