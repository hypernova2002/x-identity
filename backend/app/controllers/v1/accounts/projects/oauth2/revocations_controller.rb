module V1
  module Accounts
    module Projects
      module Oauth2
        # RFC 7009. Unknown and already revoked tokens succeed too; access tokens can't be revoked
        # and simply expire.
        class RevocationsController < BaseController
          def create
            form = oauth_params(request.request_parameters)
            app_client = ::Oidc::ClientAuthentication.new(project: current_project).authenticate(authorization: request.authorization, params: form)
            begin
              ::Auth::SignOut.new(realm: current_project.realm, app_client: app_client, **client_info).call(refresh_token: form["token"].to_s)
            rescue ApiError
              nil
            end
            head :ok
          end
        end
      end
    end
  end
end
