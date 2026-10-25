module IdentityProviders
  # Sign-in through a provider's web page, like an OAuth authorization-code flow with PKCE:
  #
  # 1. {#authorize}: the app sends the user here with its redirect URI, state and code challenge;
  #    they're sent on to the provider.
  # 2. {#callback}: the provider sends them back; the user is found, linked or created, and sent to
  #    the app's redirect URI with a short-lived code (or an error) and the app's state.
  # 3. {#redeem}: the app exchanges the code and its code verifier for tokens or a challenge, like
  #    password sign-in.
  #
  # Hosted login starts with {#authorize_for_interaction} instead; the callback then continues the
  # hosted sign-in, sending the browser back to the hosted page for any challenge.
  #
  # SAML providers get a signed AuthnRequest instead, and answer at {#saml_callback}. Providers that
  # allow it may also send unsolicited (IdP-initiated) responses, which sign the user in to the app
  # portal.
  class BrowserSignIn
    CODE_CHALLENGE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
    DISABLED_MESSAGE = "This user has been disabled. Ask an administrator to re-enable it.".freeze

    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param http_client [HttpClient]
    # @param key_set [KeySet]
    def initialize(project:, ip: nil, user_agent: nil, http_client: HttpClient.new, key_set: KeySet.new(http_client: http_client))
      @project = project
      @ip = ip
      @user_agent = user_agent
      @http_client = http_client
      @key_set = key_set
    end

    # @param provider [IdentityProvider]
    # @param app_client [AppClient]
    # @param redirect_uri [String] one of the app client's redirect URIs
    # @param state [String] returned to the app unchanged
    # @param code_challenge [String] base64url SHA-256 of the app's code verifier
    # @param issuer [String, nil] the custom domain's issuer when the app started on one; its tokens carry it
    # @return [String] the provider URL to send the user to
    # @raise [ApiError] `invalid_redirect_uri` or `validation_failed`
    def authorize(provider:, app_client:, redirect_uri:, state:, code_challenge:, issuer: nil)
      raise ApiError.new(:invalid_redirect_uri) unless app_client.redirect_uri_allowed?(redirect_uri)
      raise ApiError.validation(code_challenge: "must be the base64url SHA-256 of the code verifier") unless code_challenge.match?(CODE_CHALLENGE_FORMAT)

      provider_url(provider, "app_client_id" => app_client.id, "redirect_uri" => redirect_uri, "state" => state, "code_challenge" => code_challenge, "issuer" => issuer)
    end

    # @param provider [IdentityProvider]
    # @param interaction [OneTimeToken] the hosted login interaction
    # @param interaction_token [String] its plaintext, to send the browser back to the hosted page
    # @return [String] the provider URL to send the user to
    def authorize_for_interaction(provider:, interaction:, interaction_token:)
      provider_url(provider, "interaction_id" => interaction.id, "interaction_token" => interaction_token)
    end

    # @param state [String, nil] the state x-identity sent to the provider
    # @param code [String, nil]
    # @param error [String, nil] set by the provider when the user cancelled or it failed
    # @param apple_user [String, nil] Apple's `user` JSON, sent with the first sign-in only
    # @return [String] where to send the browser: the app's redirect URI with `code` and `state` (or
    #   `error`, `error_description` and `state`), or a hosted login page
    # @raise [ApiError] `invalid_state` when there's nowhere to send the user back to
    def callback(state:, code:, error: nil, apple_user: nil)
      record = state.present? && OneTimeToken.find_usable(state, purpose: :provider_authorization)
      raise ApiError.new(:invalid_state) unless record&.consume! && record.subject.project_id == @project.id

      provider = record.subject
      data = record.data
      resolve = ->(app_client, _interaction) { oidc_user(provider, app_client, data, code: code, error: error, apple_user: apple_user) }
      continue_after_provider(data, provider, resolve)
    end

    # @param provider [IdentityProvider] a SAML provider
    # @param saml_response [String, nil] base64, as posted to the ACS URL
    # @param relay_state [String, nil] the state sent with the AuthnRequest; anything else is unsolicited
    # @return [String] where to send the browser
    def saml_callback(provider:, saml_response:, relay_state:)
      record = relay_state.present? && OneTimeToken.find_usable(relay_state, purpose: :provider_authorization)
      if record && record.subject == provider
        raise ApiError.new(:invalid_state) unless record.consume!

        resolve = ->(app_client, interaction) { saml_user(provider, app_client, interaction, saml_response, record.data["saml_request_id"]) }
        return continue_after_provider(record.data, provider, resolve)
      end

      # Unsolicited responses arrive at the provider's ACS URL, so the portal sign-in continues on that domain.
      endpoints = provider.project_endpoints
      unless provider.allow_idp_initiated && provider.enabled?
        return endpoints.hosted_page("error", error: "invalid_request", error_description: "#{provider.name} sent a sign-in that wasn't started here. Start from the app instead.")
      end

      interaction, token = OneTimeToken.issue!(
        subject: @project.portal_client!, purpose: :oidc_interaction, replace: false, data: { "protocol" => "portal", "issuer" => endpoints.issuer }
      )
      resolve = ->(app_client, current) { saml_user(provider, app_client, current, saml_response, nil) }
      hosted_callback({ "interaction_id" => interaction.id, "interaction_token" => token }, provider, resolve)
    end

    # @param app_client [AppClient]
    # @param code [String] from the redirect to the app
    # @param code_verifier [String]
    # @param redirect_uri [String] the same redirect URI the app started with
    # @return [Auth::SignInResult]
    # @raise [ApiError] `invalid_code` or `user_disabled`
    def redeem(app_client:, code:, code_verifier:, redirect_uri:)
      record = OneTimeToken.find_usable(code, purpose: :provider_code)
      data = record&.data || {}
      valid = record && data["app_client_id"] == app_client.id && data["redirect_uri"] == redirect_uri &&
        ActiveSupport::SecurityUtils.secure_compare(data["code_challenge"].to_s, s256(code_verifier))
      raise ApiError.new(:invalid_code) unless valid && record.consume!

      end_user = record.subject
      raise ApiError.new(:user_disabled, message: DISABLED_MESSAGE) unless end_user.active?

      Auth::SignInFlow.new(realm: @project.realm(issuer: data["issuer"]), app_client: app_client, ip: @ip, user_agent: @user_agent)
        .continue(user: end_user, amr: [ "fed" ], authenticated_at: Time.zone.parse(data["authenticated_at"]))
    end

    private

    def provider_url(provider, data)
      return saml_url(provider, data) if provider.kind_saml?

      nonce = SecureRandom.base58(32)
      provider_verifier = SecureRandom.base58(64) if provider.supports_pkce?
      _record, provider_state = OneTimeToken.issue!(
        subject: provider, purpose: :provider_authorization, replace: false,
        data: data.merge("nonce" => nonce, "provider_verifier" => provider_verifier)
      )

      query = {
        response_type: "code", client_id: provider.client_id, redirect_uri: provider.callback_url,
        scope: provider.requested_scopes, state: provider_state, nonce: nonce
      }
      query.merge!(code_challenge: s256(provider_verifier), code_challenge_method: "S256") if provider_verifier
      query[:response_mode] = "form_post" if provider.kind_apple?

      "#{provider.endpoints['authorization_endpoint']}?#{query.to_query}"
    end

    def saml_url(provider, data)
      record, relay_state = OneTimeToken.issue!(subject: provider, purpose: :provider_authorization, replace: false, data: data)
      url, request_id = SamlSp::AuthnRequest.url(provider, relay_state: relay_state)
      record.update!(data: record.data.merge("saml_request_id" => request_id))
      url
    end

    # `resolve` turns the provider's answer into an end user: `->(app_client, interaction) { end_user }`.
    def continue_after_provider(data, provider, resolve)
      data["interaction_id"] ? hosted_callback(data, provider, resolve) : app_callback(data, provider, resolve)
    end

    def app_callback(data, provider, resolve)
      app_client = @project.app_clients.enabled.find_by(id: data["app_client_id"])
      raise ApiError.new(:invalid_state) unless app_client

      end_user = resolve.call(app_client, nil)
      _code_record, app_code = OneTimeToken.issue!(
        subject: end_user,
        purpose: :provider_code,
        replace: false,
        data: {
          "app_client_id" => app_client.id, "redirect_uri" => data["redirect_uri"], "code_challenge" => data["code_challenge"],
          "identity_provider_id" => provider.id, "authenticated_at" => Time.current.utc.iso8601(6), "issuer" => data["issuer"]
        }
      )
      Oidc::Urls.append_query(data["redirect_uri"], code: app_code, state: data["state"])
    rescue ApiError => failure
      raise if failure.code == :invalid_state && app_client.nil?

      Oidc::Urls.append_query(data["redirect_uri"], error: failure.code, error_description: failure.message, state: data["state"])
    end

    def hosted_callback(data, provider, resolve)
      interaction = OneTimeToken.usable.find_by(id: data["interaction_id"], purpose: "oidc_interaction")
      unless interaction&.subject&.enabled?
        return Oidc::Urls.hosted_page(@project, "error", error: "invalid_request", error_description: Oidc::Authorization::EXPIRED)
      end

      # Back to the hosted page on the domain the sign-in started on.
      endpoints = ProjectEndpoints.for_issuer(@project, interaction.data["issuer"])

      # SAML interactions have no app client; the interaction itself names the app.
      app_client = interaction.subject if interaction.subject.is_a?(AppClient)

      begin
        end_user = resolve.call(app_client, interaction)
        result = Auth::SignInFlow.new(realm: @project.realm, app_client: app_client, ip: @ip, user_agent: @user_agent, interaction: interaction)
          .continue(user: end_user, amr: [ "fed" ], authenticated_at: Time.current)
        return Oidc::Authorization.new(project: @project, ip: @ip, user_agent: @user_agent).complete(interaction, result.completion) if result.completed?

        endpoints.hosted_page("login", interaction: data["interaction_token"], challenge: result.challenge, session: result.session)
      rescue ApiError => failure
        endpoints.hosted_page("login", interaction: data["interaction_token"], error: failure.code, error_description: failure.message)
      end
    end

    def oidc_user(provider, app_client, data, code:, error:, apple_user:)
      raise ApiError.new(:identity_provider_error, message: "Signing in with #{provider.name} was cancelled or failed.") if error.present? || code.blank?
      raise ApiError.new(:invalid_state) unless provider.enabled?

      id_token = CodeRedemption.new(provider: provider, http_client: @http_client).call(code: code, code_verifier: data["provider_verifier"])
      claims = IdTokenVerifier.new(provider: provider, key_set: @key_set).verify(id_token, nonce: data["nonce"])
      UserResolver.new(provider: provider, app_client: app_client, ip: @ip, user_agent: @user_agent)
        .resolve(claims, name: apple_name(apple_user)).end_user
    end

    # Hosted sign-ins remember the SAML session, so logging out can log out of the provider too.
    def saml_user(provider, app_client, interaction, saml_response, request_id)
      raise ApiError.new(:invalid_state) unless provider.enabled?

      claims = SamlSp::ResponseValidator.new(provider).validate(saml_response, request_id: request_id)
      if interaction
        upstream = { "identity_provider_id" => provider.id, "name_id" => claims["name_id"], "name_id_format" => claims["name_id_format"], "session_index" => claims["session_index"] }
        interaction.update!(data: interaction.data.merge("upstream" => upstream))
      end
      UserResolver.new(provider: provider, app_client: app_client, ip: @ip, user_agent: @user_agent).resolve(claims).end_user
    end

    def s256(verifier)
      Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier.to_s), padding: false)
    end

    def apple_name(apple_user)
      name = JSON.parse(apple_user.to_s)["name"]
      name.is_a?(Hash) ? [ name["firstName"], name["lastName"] ].select { |part| part.is_a?(String) }.join(" ").presence : nil
    rescue JSON::ParserError
      nil
    end
  end
end
