module V1
  module Accounts
    module Projects
      module Oauth2
        class AuthorizationsController < BaseController
          # Browsers land here, so errors go back to the app when it's safe to, or to the hosted error page.
          rescue_from ::Oidc::Error do |error|
            url =
              if error.redirect_uri
                ::Oidc::Urls.append_query(error.redirect_uri, error: error.code, error_description: error.message, state: error.state, iss: current_project.token_issuer)
              else
                ::Oidc::Urls.hosted_page(current_project, "error", error: error.code, error_description: error.message)
              end
            redirect_to url, allow_other_host: true
          end

          def new
            outcome = authorization.authorize(oauth_params(request.query_parameters), session_token: session_token)
            redirect_to outcome.redirect_url, allow_other_host: true
          end

          def resume
            outcome = authorization.resume(oauth_params(request.query_parameters)["ticket"])
            store_session(outcome.session_token, outcome.session_expires_at)
            redirect_to outcome.redirect_url, allow_other_host: true
          end

          private

          def authorization
            ::Oidc::Authorization.new(project: current_project, **client_info)
          end
        end
      end
    end
  end
end
