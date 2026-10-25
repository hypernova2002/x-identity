module V1
  module Accounts
    module Projects
      module Auth
        # Sign-in with a project's identity providers: the browser redirect flow (authorize, callback,
        # token) and ID tokens from native SDKs.
        class ProvidersController < BaseController
          include Paginated

          def index
            providers = paginated(current_project.identity_providers.enabled.order(:created_at, :id))
            render json: IdentityProviderSummarySerializer.new(providers).serializable_hash
          end

          def authorize
            input = parse_request(::EndUserAuth::ProviderAuthorizeRequest, request.query_parameters).to_h
            app_client = current_project.app_clients.enabled.find_by(uid: input[:client_id])
            raise ApiError.new(:invalid_client) unless app_client

            url = browser_sign_in.authorize(
              provider: enabled_provider, app_client: app_client,
              **input.slice(:redirect_uri, :state, :code_challenge), issuer: current_endpoints.issuer
            )
            redirect_to url, allow_other_host: true
          end

          # Providers return here with GET, or with a form POST for Apple. See other (303) makes
          # browsers follow either with a GET to the app.
          def callback
            url = browser_sign_in.callback(
              state: string_param(:state), code: string_param(:code), error: string_param(:error), apple_user: string_param(:user)
            )
            redirect_to url, allow_other_host: true, status: :see_other
          end

          def token
            app_client, input = parse_client_request(::EndUserAuth::ProviderTokenRequest)
            result = browser_sign_in.redeem(app_client: app_client, **input)
            render json: SignInResultSerializer.new(result).serializable_hash
          end

          def id_token
            app_client, input = parse_client_request(::EndUserAuth::ProviderIdTokenRequest)
            provider = current_project.identity_providers.enabled.where.not(kind: "saml").find_by_uid!(params[:uid])
            result = ::IdentityProviders::NativeSignIn.new(provider: provider, app_client: app_client, issuer: current_endpoints.issuer, **client_info).call(**input)
            render json: SignInResultSerializer.new(result).serializable_hash
          end

          private

          def enabled_provider
            current_project.identity_providers.enabled.find_by_uid!(params[:uid])
          end

          def browser_sign_in
            ::IdentityProviders::BrowserSignIn.new(project: current_project, **client_info)
          end

          def string_param(name)
            value = params[name]
            value if value.is_a?(String)
          end
        end
      end
    end
  end
end
