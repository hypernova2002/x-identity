module V1
  module Accounts
    module Projects
      module Auth
        class PasswordResetsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::ForgotPasswordRequest)
            password_reset(app_client).request(**input)
            head :accepted
          end

          def update
            app_client, input = parse_client_request(::EndUserAuth::ConfirmForgotPasswordRequest)
            password_reset(app_client).confirm(**input)
            head :no_content
          end

          private

          def password_reset(app_client)
            ::EndUsers::PasswordReset.new(project: current_project, app_client: app_client, **client_info)
          end
        end
      end
    end
  end
end
