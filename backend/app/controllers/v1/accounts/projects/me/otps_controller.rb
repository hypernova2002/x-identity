module V1
  module Accounts
    module Projects
      module Me
        class OtpsController < EndUserController
          def create
            render json: MfaEnrollmentSerializer.new(enrollment.start(**parse_request(::Me::StartOtpRequest).to_h)).serializable_hash, status: :created
          end

          def confirm
            render json: { recovery_codes: enrollment.confirm(**parse_request(::Me::ConfirmOtpRequest).to_h) }
          end

          def destroy
            enrollment.disable(**parse_request(::Me::DisableOtpRequest).to_h)
            head :no_content
          end

          private

          def enrollment
            ::Mfa::OtpEnrollment.new(user: current_user, **client_info)
          end
        end
      end
    end
  end
end
