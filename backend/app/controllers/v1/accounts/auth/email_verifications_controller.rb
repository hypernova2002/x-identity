module V1
  module Accounts
    module Auth
      class EmailVerificationsController < BaseController
        def create
          email_verification.request(**EmailRequest.from_params(params).to_h)
          head :accepted
        end

        def update
          email_verification.confirm(**TokenRequest.from_params(params).to_h)
          head :no_content
        end

        private

        def email_verification
          ::Auth::EmailVerification.new(account: current_account, request_context: request_context)
        end
      end
    end
  end
end
