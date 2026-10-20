module V1
  module Accounts
    module Me
      class RecoveryCodesController < AuthenticatedController
        def create
          codes = ::Mfa::TotpEnrollment.new(user: current_user).regenerate_recovery_codes(**CodeRequest.from_params(params).to_h)
          render json: { recovery_codes: codes }, status: :created
        end
      end
    end
  end
end
