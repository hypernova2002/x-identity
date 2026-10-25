module V1
  module Accounts
    module Projects
      module Auth
        class SignInsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::SignInRequest)
            result = ::Auth::SignIn.new(context: sign_in_context(app_client)).call(**input)
            render json: SignInResultSerializer.new(result).serializable_hash
          end
        end
      end
    end
  end
end
