module V1
  module Accounts
    module Projects
      module Me
        class RecoveryCodesController < EndUserController
          def create
            codes = ::Mfa::OtpEnrollment.new(user: current_user, **client_info)
              .regenerate_recovery_codes(**parse_request(::Me::RegenerateRecoveryCodesRequest).to_h)
            render json: { recovery_codes: codes }, status: :created
          end
        end
      end
    end
  end
end
