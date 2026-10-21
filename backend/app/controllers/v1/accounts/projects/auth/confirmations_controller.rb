module V1
  module Accounts
    module Projects
      module Auth
        class ConfirmationsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::ConfirmSignUpRequest)
            confirmation(app_client).confirm(**input)
            head :no_content
          end

          def resend
            app_client, input = parse_client_request(::EndUserAuth::ResendConfirmationRequest)
            confirmation(app_client).resend(**input)
            head :accepted
          end

          private

          def confirmation(app_client)
            ::EndUsers::Confirmation.new(project: current_project, app_client: app_client, **client_info)
          end
        end
      end
    end
  end
end
