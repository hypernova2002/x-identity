module V1
  module Accounts
    module Me
      class EmailChangesController < AuthenticatedController
        def create
          ::Users::EmailChange.new(account: current_account, **client_info)
            .request(user: current_user, **parse_request(::Me::EmailChangeRequest).to_h)
          head :accepted
        end
      end
    end
  end
end
