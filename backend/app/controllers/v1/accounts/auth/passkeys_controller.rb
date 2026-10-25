module V1
  module Accounts
    module Auth
      # Console sign-in with a passkey, as a first factor or to answer a second-factor challenge, and
      # setting one up when passkeys are required.
      class PasskeysController < BaseController
        rate_limit to: 30, within: 1.minute, only: %i[options challenge_options]

        def options
          render json: authentication.options
        end

        def create
          user, amr = authentication.verify(**parse_request(::Passkeys::SignInRequest).to_h)
          result = ::Auth::SignInFlow.new(context: sign_in_context).continue(user: user, amr: amr, authenticated_at: Time.current)
          render json: SignInResultSerializer.new(result).serializable_hash
        end

        def challenge_options
          render json: ::Auth::ChallengeResponse.new(context: sign_in_context).passkey_options(**parse_request(::Passkeys::ChallengeOptionsRequest).to_h)
        end

        def setup
          render json: ::Auth::ChallengeResponse.new(context: sign_in_context).start_passkey_setup(**parse_request(::Passkeys::SetupRequest).to_h)
        end

        private

        def realm
          current_account.realm
        end

        def sign_in_context
          ::Auth::SignInContext.new(realm: realm, **client_info)
        end

        def authentication
          ::Passkeys::Authentication.new(realm: realm, relying_party: ::Passkeys::RelyingParties.for_realm(realm))
        end
      end
    end
  end
end
