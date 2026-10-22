module SamlIdp
  # SAML single sign-on: AuthnRequests from apps (SP-initiated) and launches from the app portal
  # (IdP-initiated). A browser with a valid single sign-on session gets a response straight away;
  # otherwise the user signs in on the hosted login page first, which ends in {#respond}.
  class SignOn
    Outcome = Data.define(:redirect_url, :html) do
      def initialize(redirect_url: nil, html: nil)
        super
      end
    end

    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param params [Hash{String => String}] SAMLRequest and RelayState
    # @param raw_query [String] the query string, for Redirect-binding signatures
    # @param binding [Symbol] :redirect or :post
    # @param session_token [String, nil] from the single sign-on cookie
    # @return [Outcome]
    def sso(params:, raw_query:, binding:, session_token:)
      document, xml = Messages.decode(params["SAMLRequest"], deflated: binding == :redirect)
      request = document.at_xpath("/samlp:AuthnRequest", Messages::NAMESPACES)
      return error_page("This isn't a SAML sign-in request.") unless request

      issuer = request.at_xpath("saml:Issuer", Messages::NAMESPACES)&.text.to_s.strip
      app = @project.saml_apps.enabled.find_by(entity_id: issuer)
      return error_page("The app #{issuer.presence || '(unnamed)'} isn't set up for SAML sign-in with this project, or is disabled.") unless app
      return error_page("The sign-in request from #{app.name} isn't signed correctly.") unless signature_valid?(app, binding, raw_query, xml)

      acs_url = request["AssertionConsumerServiceURL"].presence || app.default_acs_url
      return error_page("#{app.name} asked to receive the sign-in at an address that isn't registered.") unless app.acs_url_allowed?(acs_url)
      if request["ProtocolBinding"].present? && request["ProtocolBinding"] != Messages::POST_BINDING
        return error_page("#{app.name} asked for a response binding that isn't supported. Use HTTP-POST.")
      end

      data = { "protocol" => "saml", "request_id" => request["ID"].presence, "acs_url" => acs_url, "relay_state" => params["RelayState"].presence }
      sign_in(app, data, session_token, force: request["ForceAuthn"] == "true", passive: request["IsPassive"] == "true")
    rescue Messages::Error => error
      error_page(error.message)
    end

    # IdP-initiated sign-in, e.g. from the app portal.
    # @param app [SamlApp]
    # @param session_token [String, nil]
    # @return [Outcome]
    def launch(app, session_token:)
      data = { "protocol" => "saml", "request_id" => nil, "acs_url" => app.default_acs_url, "relay_state" => app.default_relay_state.presence }
      sign_in(app, data, session_token, force: false, passive: false)
    end

    # Sends the signed-in user to the app with a SAML Response, and remembers the app in the
    # browser session for single logout.
    # @param app [SamlApp]
    # @param data [Hash] the request: acs_url, request_id and relay_state
    # @param session [BrowserSession]
    # @return [Outcome]
    def respond(app, data, session)
      end_user = session.end_user
      Apps::Access.authorize!(app, end_user, recorder: recorder)

      builder = ResponseBuilder.new(app)
      participation = session.browser_session_apps.find_or_initialize_by(saml_app: app)
      participation.session_index ||= Messages.new_id
      participation.update!(name_id: builder.name_id_for(end_user))

      saml_response = builder.success(
        end_user: end_user, acs_url: data["acs_url"], in_response_to: data["request_id"],
        session_index: participation.session_index, authenticated_at: session.authenticated_at, amr: session.amr
      )
      recorder.record(action: "end_user.signed_in_to_app", actor: end_user, target: end_user, metadata: { saml_app: app.uid, app_name: app.name, amr: session.amr })
      Outcome.new(html: PostForm.html(data["acs_url"], "SAMLResponse" => saml_response, "RelayState" => data["relay_state"]))
    rescue ApiError => error
      error_page(error.message, code: error.code.to_s)
    end

    private

    def sign_in(app, data, session_token, force:, passive:)
      session = BrowserSession.find_valid(session_token, project: @project)
      if session && !force
        session.update_column(:last_used_at, Time.current)
        return respond(app, data, session)
      end

      if passive
        failure = ResponseBuilder.new(app).failure(acs_url: data["acs_url"], in_response_to: data["request_id"], status: "Responder", sub_status: "NoPassive")
        return Outcome.new(html: PostForm.html(data["acs_url"], "SAMLResponse" => failure, "RelayState" => data["relay_state"]))
      end

      _record, interaction = OneTimeToken.issue!(subject: app, purpose: :oidc_interaction, replace: false, data: data)
      Outcome.new(redirect_url: Oidc::Urls.hosted_page(@project, "login", interaction: interaction))
    end

    def signature_valid?(app, binding, raw_query, xml)
      return true unless app.require_signed_requests

      certificate = app.certificate
      return false unless certificate

      binding == :redirect ? Messages.redirect_signature_valid?(raw_query, type: "SAMLRequest", certificate: certificate) : Messages.embedded_signature_valid?(xml, certificate)
    end

    def error_page(description, code: "invalid_request")
      Outcome.new(redirect_url: Oidc::Urls.hosted_page(@project, "error", error: code, error_description: description))
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
