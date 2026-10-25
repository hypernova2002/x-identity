module V1
  module Accounts
    module Projects
      module Oauth2
        class LogoutsController < BaseController
          def create
            form = oauth_params(request.query_parameters.merge(request.request_parameters))
            url = ::Oidc::Logout.new(project: current_project, endpoints: current_endpoints, **client_info).call(session_token: session_token, params: form)
            clear_session
            redirect_to url, allow_other_host: true, status: :see_other
          end
        end
      end
    end
  end
end
