module V1
  module Accounts
    module Projects
      module Oauth2
        class TokensController < BaseController
          def create
            no_store!
            form = oauth_params(request.request_parameters)
            app_client = ::Oidc::ClientAuthentication.new(project: current_project).authenticate(authorization: request.authorization, params: form)
            render json: ::Oidc::TokenExchange.new(project: current_project, **client_info).call(app_client: app_client, params: form)
          end
        end
      end
    end
  end
end
