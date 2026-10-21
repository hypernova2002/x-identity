module V1
  module Accounts
    module Projects
      module Auth
        class SignOutsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::SignOutRequest)
            ::Auth::SignOut.new(realm: realm, app_client: app_client, **client_info).call(**input)
            head :no_content
          end
        end
      end
    end
  end
end
