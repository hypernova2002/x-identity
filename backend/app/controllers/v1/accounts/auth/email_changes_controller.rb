module V1
  module Accounts
    module Auth
      class EmailChangesController < BaseController
        def update
          ::Users::EmailChange.new(account: current_account, **client_info)
            .confirm(**parse_request(::Auth::ConfirmEmailChangeRequest).to_h)
          head :no_content
        end
      end
    end
  end
end
