module Passkeys
  # The relying party (WebAuthn's name for the site passkeys belong to): the console's host for
  # console users, a project's verified custom domain for its end users. Only while passkeys are
  # turned on for them.
  #
  # End users' passkeys can be used on the custom domain itself (hosted login and the app portal),
  # and from an app client's own allowed origins, e.g. its sign-in screen at app.acme.com: the
  # domain lists those in /.well-known/webauthn, so browsers let them use its passkeys.
  module RelyingParties
    module_function

    # @param user [User, EndUser]
    # @param endpoints [ProjectEndpoints, nil] where an end user's request arrived
    # @param app_client [AppClient, nil] the app an end user's request comes from
    # @return [WebAuthn::RelyingParty]
    # @raise [ApiError] `passkeys_unavailable`
    def for(user, endpoints: nil, app_client: nil)
      for_realm(user.realm, endpoints: endpoints, app_client: app_client)
    end

    # For signing in, before the user is known.
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param endpoints [ProjectEndpoints, nil] where an end user's request arrived: the custom
    #   domain's own pages can use its passkeys
    # @param app_client [AppClient, nil] its allowed origins can use them too
    # @return [WebAuthn::RelyingParty]
    # @raise [ApiError] `passkeys_unavailable`
    def for_realm(realm, endpoints: nil, app_client: nil)
      raise ApiError.new(:passkeys_unavailable) unless realm.auth_configuration.passkeys_optional?
      return console(realm.account) if realm.is_a?(Realms::AccountRealm)

      domain = realm.project.domains.status_verified.first
      origins = []
      origins << domain.base_url if domain && endpoints&.domain == domain
      origins.concat(Array(app_client&.allowed_origins)) if domain
      raise ApiError.new(:passkeys_unavailable, message: "Passkeys work on the project's custom domain, and from its apps' allowed origins.") if origins.empty?

      WebAuthn::RelyingParty.new(id: domain.hostname, allowed_origins: origins.uniq, name: realm.display_name)
    end

    # Where a user part-way through signing in could use a passkey as their second factor: the
    # console for console users; for end users, the custom domain hosted login started on, or the
    # allowed origins of the app signing them in through the API.
    # @param user [User, EndUser]
    # @param interaction [OneTimeToken, nil] the hosted login interaction
    # @param app_client [AppClient, nil] the app, for sign-ins through the API
    # @return [WebAuthn::RelyingParty, nil]
    def for_sign_in(user, interaction: nil, app_client: nil)
      return for_realm(user.realm) if user.is_a?(User)
      return for_realm(user.realm, endpoints: ProjectEndpoints.for_issuer(user.project, interaction.data["issuer"])) if interaction

      app_client ? for_realm(user.realm, app_client: app_client) : nil
    rescue ApiError
      nil
    end

    # Other origins that can use a project's passkeys, for /.well-known/webauthn on its custom domain.
    # @param project [Project]
    # @return [Array<String>]
    def related_origins(project)
      domain = project.domains.status_verified.first
      return [] unless domain && project.auth_configuration!.passkeys_optional?

      project.app_clients.enabled.where(machine: false).pluck(:allowed_origins).flatten.uniq.sort - [ domain.base_url ]
    end

    def console(account)
      url = URI.parse(Rails.configuration.x.console_base_url)
      origin = "#{url.scheme}://#{url.host}#{":#{url.port}" unless url.port == url.default_port}"
      WebAuthn::RelyingParty.new(id: url.host, allowed_origins: [ origin ], name: account.name)
    end
  end
end
