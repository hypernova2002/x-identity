module Oidc
  # The authorization endpoint of a project's OpenID Connect provider (code flow with PKCE).
  # Hosted login interactions for SAML apps finish here too, with a SAML response instead of a code.
  #
  # A browser with a valid single sign-on session gets a code straight away. Otherwise an
  # interaction is started and the browser goes to the hosted login page; once the user has signed
  # in there, {#complete} hands the page a ticket, and {#resume} turns the ticket into a session
  # cookie and a code for the app.
  class Authorization
    Outcome = Data.define(:redirect_url, :html, :session_token, :session_expires_at) do
      def initialize(redirect_url: nil, html: nil, session_token: nil, session_expires_at: nil)
        super
      end
    end

    SUPPORTED_SCOPES = %w[openid profile email groups offline_access].freeze
    CODE_CHALLENGE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
    MAX_AGE_FORMAT = /\A\d{1,9}\z/
    LIMITS = { "state" => 1024, "nonce" => 512, "login_hint" => 254 }.freeze
    EXPIRED = "This sign-in has expired. Go back to the app and try again.".freeze

    # @param project [Project]
    # @param endpoints [ProjectEndpoints] where the request arrived; an interaction remembers it, so
    #   the rest of the sign-in stays there
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, endpoints: ProjectEndpoints.new(project), ip: nil, user_agent: nil)
      @project = project
      @endpoints = endpoints
      @ip = ip
      @user_agent = user_agent
    end

    # @param params [Hash{String => String}] the authorization request's query parameters
    # @param session_token [String, nil] from the single sign-on cookie
    # @return [Outcome]
    # @raise [Error] redirected to the app once its client and redirect URI are known to be valid
    def authorize(params, session_token: nil)
      app_client = @project.app_clients.enabled.where(machine: false).find_by(uid: params["client_id"].to_s)
      raise Error.new("invalid_request", "This app isn't registered with the project, or is disabled.") unless app_client

      redirect_uri = params["redirect_uri"].to_s
      raise Error.new("invalid_request", "The redirect URI isn't registered for this app.") unless app_client.redirect_uri_allowed?(redirect_uri)

      state = params["state"].presence
      request = validated_request(params, redirect_uri, state)
      prompts = params["prompt"].to_s.split(" ")

      session = BrowserSession.find_valid(session_token, project: @project)
      if session && !prompts.include?("login") && fresh?(session, params["max_age"])
        unless Apps::Access.allowed?(app_client, session.end_user)
          raise Error.new("access_denied", ApiError.new(:app_access_denied).message, redirect_uri: redirect_uri, state: state)
        end

        session.update_column(:last_used_at, Time.current)
        session.device_session&.touch_activity!(ip: @ip, user_agent: @user_agent)
        record_sso_sign_in(session, app_client)
        return Outcome.new(redirect_url: code_redirect(app_client, request, session, session.amr, session.authenticated_at, @endpoints))
      end
      raise Error.new("login_required", "The user needs to sign in.", redirect_uri: redirect_uri, state: state) if prompts.include?("none")

      _record, interaction = OneTimeToken.issue!(
        subject: app_client, purpose: :oidc_interaction, replace: false,
        data: request.merge("login_hint" => params["login_hint"].presence, "issuer" => @endpoints.issuer)
      )
      Outcome.new(redirect_url: @endpoints.hosted_page("login", interaction: interaction))
    end

    # Called when the user has signed in on the hosted login page.
    # @param interaction [OneTimeToken]
    # @param completion [Auth::SignInCompletion]
    # @return [String] where the page sends the browser next
    def complete(interaction, completion)
      _record, ticket = OneTimeToken.issue!(
        subject: completion.user, purpose: :oidc_login_ticket, replace: false,
        data: { "interaction_id" => interaction.id, "amr" => completion.amr, "authenticated_at" => completion.authenticated_at.utc.iso8601(6) }
      )
      interaction_endpoints(interaction).url("/oauth2/authorize/resume?#{{ ticket: ticket }.to_query}")
    end

    # @param ticket [String, nil]
    # @return [Outcome] with the new session's cookie token
    # @raise [Error] when the ticket or its interaction is no longer usable
    def resume(ticket)
      record = ticket.present? && OneTimeToken.find_usable(ticket, purpose: :oidc_login_ticket)
      raise Error.new("invalid_request", EXPIRED) unless record&.consume!

      interaction = OneTimeToken.usable.find_by(id: record.data["interaction_id"], purpose: "oidc_interaction")
      app = interaction&.subject
      valid = interaction&.consume! && app.project_id == @project.id && app.enabled? && record.subject.active?
      raise Error.new("invalid_request", EXPIRED) unless valid

      endpoints = interaction_endpoints(interaction)
      end_user = record.subject
      amr = record.data["amr"]
      authenticated_at = Time.iso8601(record.data["authenticated_at"])
      session, token = BrowserSession.start!(
        end_user: end_user, amr: amr, authenticated_at: authenticated_at, upstream: interaction.data["upstream"], ip: @ip, user_agent: @user_agent
      )

      response =
        if app.is_a?(SamlApp)
          SamlIdp::SignOn.new(project: @project, endpoints: endpoints, ip: @ip, user_agent: @user_agent).respond(app, interaction.data, session).to_h.slice(:redirect_url, :html)
        elsif interaction.data["protocol"] == "portal"
          { redirect_url: endpoints.hosted_page("apps") }
        else
          { redirect_url: code_redirect(app, interaction.data, session, amr, authenticated_at, endpoints) }
        end
      Outcome.new(**response, session_token: token, session_expires_at: session.expires_at)
    end

    private

    def validated_request(params, redirect_uri, state)
      fail_with = ->(code, description) { raise Error.new(code, description, redirect_uri: redirect_uri, state: state) }

      fail_with.call("unsupported_response_type", "Only the code response type is supported.") unless params["response_type"] == "code"
      scopes = params["scope"].to_s.split(" ")
      fail_with.call("invalid_scope", "The scope must include openid.") unless scopes.include?("openid")
      unless params["code_challenge_method"] == "S256" && params["code_challenge"].to_s.match?(CODE_CHALLENGE_FORMAT)
        fail_with.call("invalid_request", "PKCE is required: send an S256 code_challenge.")
      end
      prompts = params["prompt"].to_s.split(" ")
      fail_with.call("invalid_request", "prompt=none can't be combined with other values.") if prompts.include?("none") && prompts.size > 1
      fail_with.call("invalid_request", "max_age must be a number of seconds.") if params["max_age"].present? && !params["max_age"].match?(MAX_AGE_FORMAT)
      LIMITS.each do |name, limit|
        fail_with.call("invalid_request", "#{name} is too long.") if params[name].to_s.length > limit
      end

      {
        "redirect_uri" => redirect_uri,
        "state" => state,
        "nonce" => params["nonce"].presence,
        "code_challenge" => params["code_challenge"],
        "scope" => (scopes & SUPPORTED_SCOPES).join(" ")
      }
    end

    def fresh?(session, max_age)
      max_age.blank? || session.authenticated_at >= max_age.to_i.seconds.ago
    end

    # @param interaction [OneTimeToken]
    # @return [ProjectEndpoints] where the interaction started
    def interaction_endpoints(interaction)
      ProjectEndpoints.for_issuer(@project, interaction.data["issuer"])
    end

    def code_redirect(app_client, request, session, amr, authenticated_at, endpoints)
      _record, code = OneTimeToken.issue!(
        subject: session.end_user, purpose: :oidc_code, replace: false,
        data: {
          "app_client_id" => app_client.id, "redirect_uri" => request["redirect_uri"], "code_challenge" => request["code_challenge"],
          "nonce" => request["nonce"], "scope" => request["scope"], "amr" => amr, "authenticated_at" => authenticated_at.utc.iso8601(6),
          "device_session_id" => session.device_session_id, "issuer" => endpoints.issuer
        }
      )
      Urls.append_query(request["redirect_uri"], code: code, state: request["state"], iss: endpoints.issuer)
    end

    def record_sso_sign_in(session, app_client)
      session.end_user.record_sign_in!
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: app_client).record(
        action: "end_user.signed_in", actor: session.end_user, target: session.end_user, metadata: { amr: session.amr, sso: true }
      )
    end
  end
end
