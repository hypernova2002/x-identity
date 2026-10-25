module Passkeys
  # The relying party (WebAuthn's name for the site passkeys belong to) for a user: the console's
  # host for console users, a project's verified custom domain for its end users. Only while
  # passkeys are turned on for them.
  module RelyingParties
    module_function

    # @param user [User, EndUser]
    # @param endpoints [ProjectEndpoints, nil] where an end user's request arrived
    # @return [WebAuthn::RelyingParty]
    # @raise [ApiError] `passkeys_unavailable`
    def for(user, endpoints: nil)
      raise ApiError.new(:passkeys_unavailable) unless user.realm.auth_configuration.passkeys_optional?
      return console(user.account) if user.is_a?(User)

      domain = endpoints&.domain
      raise ApiError.new(:passkeys_unavailable, message: "Passkeys work on the project's custom domain.") unless domain

      WebAuthn::RelyingParty.new(id: domain.hostname, allowed_origins: [ domain.base_url ], name: user.project.realm.display_name)
    end

    def console(account)
      url = URI.parse(Rails.configuration.x.console_base_url)
      origin = "#{url.scheme}://#{url.host}#{":#{url.port}" unless url.port == url.default_port}"
      WebAuthn::RelyingParty.new(id: url.host, allowed_origins: [ origin ], name: account.name)
    end
  end
end
