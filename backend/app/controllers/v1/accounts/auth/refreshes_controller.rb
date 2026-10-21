module V1
  module Accounts
    module Auth
      class RefreshesController < BaseController
        def create
          tokens = ::Auth::Refresh.new(realm: current_account.realm, **client_info)
            .call(**parse_request(::Auth::RefreshRequest).to_h)
          render json: TokenSetSerializer.new(tokens).serializable_hash
        end
      end
    end
  end
end
