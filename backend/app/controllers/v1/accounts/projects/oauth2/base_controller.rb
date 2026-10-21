module V1
  module Accounts
    module Projects
      module Oauth2
        # A project's OAuth 2.0 / OpenID Connect endpoints. Errors use the protocol's format
        # (`error`, `error_description`) because standard client libraries expect it.
        class BaseController < Projects::BaseController
          include ActionController::Cookies

          rescue_from ::Oidc::Error do |error|
            response.headers["WWW-Authenticate"] = 'Basic realm="x-identity"' if error.status == 401
            render json: error.body, status: error.status
          end

          private

          # Protocol parameters, keeping only string values.
          # @param source [Hash]
          # @return [Hash{String => String}]
          def oauth_params(source)
            source.to_h.select { |_name, value| value.is_a?(String) }.transform_keys(&:to_s)
          end

          def no_store!
            response.headers["Cache-Control"] = "no-store"
            response.headers["Pragma"] = "no-cache"
          end

          def session_token
            cookies[BrowserSession::COOKIE_NAME]
          end

          def store_session(token, expires_at)
            cookies[BrowserSession::COOKIE_NAME] = { value: token, expires: expires_at, **cookie_options }
          end

          def clear_session
            cookies.delete(BrowserSession::COOKIE_NAME, **cookie_options)
          end

          # Scoped to this project's OAuth endpoints, so each project has its own session.
          def cookie_options
            {
              path: "#{URI.parse(current_project.token_issuer).path}/oauth2",
              httponly: true,
              same_site: :lax,
              secure: Rails.configuration.x.app_base_url.start_with?("https://")
            }
          end
        end
      end
    end
  end
end
