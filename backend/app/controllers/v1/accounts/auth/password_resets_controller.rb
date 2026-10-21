module V1
  module Accounts
    module Auth
      class PasswordResetsController < BaseController
        def create
          password_reset.request(**parse_request(::Auth::ForgotPasswordRequest).to_h)
          head :accepted
        end

        def update
          password_reset.reset(**parse_request(::Auth::ResetPasswordRequest).to_h)
          head :no_content
        end

        private

        def password_reset
          ::Auth::PasswordReset.new(account: current_account, **client_info)
        end
      end
    end
  end
end
