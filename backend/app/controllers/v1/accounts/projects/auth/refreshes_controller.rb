module V1
  module Accounts
    module Projects
      module Auth
        class RefreshesController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::RefreshRequest)
            tokens = ::Auth::Refresh.new(realm: realm, app_client: app_client, **client_info).call(**input)
            render json: TokenSetSerializer.new(tokens).serializable_hash
          end
        end
      end
    end
  end
end
