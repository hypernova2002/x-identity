module V1
  module Accounts
    module Auth
      class EmailVerificationsController < BaseController
        def create
          email_verification.request(**parse_request(::Auth::ResendConfirmationRequest).to_h)
          head :accepted
        end

        def update
          email_verification.confirm(**parse_request(::Auth::ConfirmEmailRequest).to_h)
          head :no_content
        end

        private

        def email_verification
          ::Auth::EmailVerification.new(account: current_account, **client_info)
        end
      end
    end
  end
end
