module V1
  module Accounts
    module Projects
      # /.well-known/webauthn on a project's custom domain: the other origins (its apps' own sign-in
      # screens) that browsers let use the domain's passkeys. See WebAuthn related origin requests.
      class WebauthnRelatedOriginsController < PublicController
        def show
          cache_publicly(5.minutes)
          render json: { origins: ::Passkeys::RelyingParties.related_origins(current_project) }
        end
      end
    end
  end
end
