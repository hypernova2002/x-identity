module V1
  module Accounts
    module Me
      class EmailChangesController < AuthenticatedController
        def create
          ::Users::EmailChange.new(account: current_account, request_context: request_context)
            .request(user: current_user, **EmailChangeRequest.from_params(params).to_h)
          head :accepted
        end
      end
    end
  end
end
