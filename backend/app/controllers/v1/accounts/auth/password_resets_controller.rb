module V1
  module Accounts
    module Auth
      class PasswordResetsController < BaseController
        def create
          password_reset.request(**EmailRequest.from_params(params).to_h)
          head :accepted
        end

        def update
          password_reset.reset(**ResetPasswordRequest.from_params(params).to_h)
          head :no_content
        end

        private

        def password_reset
          ::Auth::PasswordReset.new(account: current_account, request_context: request_context)
        end
      end
    end
  end
end
