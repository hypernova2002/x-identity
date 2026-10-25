module V1
  module Accounts
    module Projects
      module Auth
        # Passkey sign-in for an app's own sign-in screen. The browser page must be on one of the app
        # client's allowed origins, which the project's custom domain lists in /.well-known/webauthn.
        class PasskeysController < BaseController
          rate_limit to: 30, within: 1.minute, only: %i[options challenge_options]

          def options
            app_client, = parse_client_request(::EndUserAuth::PasskeyOptionsRequest)
            render json: authentication(app_client).options
          end

          def create
            app_client, input = parse_client_request(::EndUserAuth::PasskeySignInRequest)
            user, amr = authentication(app_client).verify(**input)
            result = ::Auth::SignInFlow.new(context: sign_in_context(app_client)).continue(user: user, amr: amr, authenticated_at: Time.current)
            render json: SignInResultSerializer.new(result).serializable_hash
          end

          def challenge_options
            app_client, input = parse_client_request(::EndUserAuth::PasskeyChallengeOptionsRequest)
            render json: ::Auth::ChallengeResponse.new(context: sign_in_context(app_client)).passkey_options(**input)
          end

          def setup
            app_client, input = parse_client_request(::EndUserAuth::PasskeySetupRequest)
            render json: ::Auth::ChallengeResponse.new(context: sign_in_context(app_client)).start_passkey_setup(**input)
          end

          private

          def authentication(app_client)
            ::Passkeys::Authentication.new(realm: realm, relying_party: ::Passkeys::RelyingParties.for_realm(realm, app_client: app_client))
          end
        end
      end
    end
  end
end
