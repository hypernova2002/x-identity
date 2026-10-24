module V1
  module Accounts
    module Projects
      module Oauth2
        class TokensController < BaseController
          def create
            no_store!
            form = oauth_params(request.request_parameters)
            app_client = ::Oidc::ClientAuthentication.new(project: current_project).authenticate(authorization: request.authorization, params: form)
            rate_limit(app_client)
            render json: ::Oidc::TokenExchange.new(project: current_project, **client_info).call(app_client: app_client, params: form)
          end

          private

          def rate_limit(app_client)
            ::Oidc::TokenRateLimit.new(app_client).check!
          rescue ::Oidc::Error => error
            current_project.realm.recorder(**client_info, app_client: app_client).record(
              action: "app_client.token_refused", actor: app_client, metadata: { error: error.code, limit: app_client.token_rate_limit }
            )
            raise
          end
        end
      end
    end
  end
end
