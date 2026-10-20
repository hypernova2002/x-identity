module V1
  module Accounts
    module Auth
      class EmailChangesController < BaseController
        def update
          ::Users::EmailChange.new(account: current_account, request_context: request_context).confirm(**TokenRequest.from_params(params).to_h)
          head :no_content
        end
      end
    end
  end
end
