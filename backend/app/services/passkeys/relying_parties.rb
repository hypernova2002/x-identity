module Passkeys
  # The relying party (WebAuthn's name for the site passkeys belong to): the console's host for
  # console users, a project's verified custom domain for its end users. Only while passkeys are
  # turned on for them.
  module RelyingParties
    module_function

    # @param user [User, EndUser]
    # @param endpoints [ProjectEndpoints, nil] where an end user's request arrived
    # @return [WebAuthn::RelyingParty]
    # @raise [ApiError] `passkeys_unavailable`
    def for(user, endpoints: nil)
      for_realm(user.realm, endpoints: endpoints)
    end

    # For signing in, before the user is known.
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm]
    # @param endpoints [ProjectEndpoints, nil] where an end user's request arrived
    # @return [WebAuthn::RelyingParty]
    # @raise [ApiError] `passkeys_unavailable`
    def for_realm(realm, endpoints: nil)
      raise ApiError.new(:passkeys_unavailable) unless realm.auth_configuration.passkeys_optional?
      return console(realm.account) if realm.is_a?(Realms::AccountRealm)

      domain = endpoints&.domain
      raise ApiError.new(:passkeys_unavailable, message: "Passkeys work on the project's custom domain.") unless domain

      WebAuthn::RelyingParty.new(id: domain.hostname, allowed_origins: [ domain.base_url ], name: realm.display_name)
    end

    # Where a user part-way through signing in could use a passkey as their second factor: the
    # console for console users, the custom domain hosted login started on for end users. Sign-ins
    # through the API on a custom domain don't offer passkeys yet.
    # @param user [User, EndUser]
    # @param interaction [OneTimeToken, nil] the hosted login interaction
    # @return [WebAuthn::RelyingParty, nil]
    def for_sign_in(user, interaction: nil)
      endpoints = ProjectEndpoints.for_issuer(user.project, interaction.data["issuer"]) if user.is_a?(EndUser) && interaction
      for_realm(user.realm, endpoints: endpoints)
    rescue ApiError
      nil
    end

    def console(account)
      url = URI.parse(Rails.configuration.x.console_base_url)
      origin = "#{url.scheme}://#{url.host}#{":#{url.port}" unless url.port == url.default_port}"
      WebAuthn::RelyingParty.new(id: url.host, allowed_origins: [ origin ], name: account.name)
    end
  end
end
