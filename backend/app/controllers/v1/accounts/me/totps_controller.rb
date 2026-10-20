module V1
  module Accounts
    module Me
      class TotpsController < AuthenticatedController
        def create
          render json: MfaEnrollmentSerializer.new(enrollment.start).serializable_hash, status: :created
        end

        def confirm
          render json: { recovery_codes: enrollment.confirm(**CodeRequest.from_params(params).to_h) }
        end

        def destroy
          enrollment.disable(**DisableTotpRequest.from_params(params).to_h)
          head :no_content
        end

        private

        def enrollment
          ::Mfa::TotpEnrollment.new(user: current_user)
        end
      end
    end
  end
end
