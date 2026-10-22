module SamlIdp
  # SAML single logout. Ending a browser session logs the user out of every SAML app it signed in
  # to, one front-channel redirect at a time: each app gets a LogoutRequest and answers with a
  # LogoutResponse to {#receive}, which moves on to the next. The chain then ends where it started:
  # with a LogoutResponse to the app that asked, or at a URL (hosted logout and the app portal).
  class Logout
    CHAIN_TTL = 10.minutes
    SUCCESS = "urn:oasis:names:tc:SAML:2.0:status:Success".freeze

    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # Logs the session out of its SAML apps, then sends the browser to `final_url`.
    # @param session [BrowserSession] already revoked
    # @param final_url [String]
    # @return [String] where to send the browser
    def start(session, final_url:)
      continue_chain(new_chain(session, { "type" => "url", "url" => final_url }))
    end

    # A LogoutRequest from an app, or an app's LogoutResponse during a chain.
    # @param params [Hash{String => String}]
    # @param raw_query [String]
    # @param binding [Symbol] :redirect or :post
    # @param session_token [String, nil] from the single sign-on cookie
    # @return [String] where to send the browser
    def receive(params:, raw_query:, binding:, session_token:)
      return response_received(params) if params["SAMLResponse"].present?

      document, xml = Messages.decode(params["SAMLRequest"], deflated: binding == :redirect)
      request = document.at_xpath("/samlp:LogoutRequest", Messages::NAMESPACES)
      return error_page("This isn't a SAML logout request.") unless request

      app = @project.saml_apps.find_by(entity_id: request.at_xpath("saml:Issuer", Messages::NAMESPACES)&.text.to_s.strip)
      return error_page("The app asking to log out isn't set up for SAML with this project.") unless app
      return error_page("The logout request from #{app.name} isn't signed correctly.") unless signature_valid?(app, binding, raw_query, xml)

      session = session_for(session_token, app, request)
      origin = { "type" => "saml", "app_id" => app.id, "request_id" => request["ID"], "relay_state" => params["RelayState"].presence }
      return finish(origin) unless session

      end_session(session)
      continue_chain(new_chain(session, origin, except: app))
    rescue Messages::Error => error
      error_page(error.message)
    end

    private

    def response_received(params)
      chain = params["RelayState"].present? && OneTimeToken.find_usable(params["RelayState"], purpose: :saml_logout)
      return Oidc::Urls.hosted_page(@project, "signed-out") unless chain

      continue_chain(chain, token: params["RelayState"])
    end

    def new_chain(session, origin, except: nil)
      pending = session.browser_session_apps.includes(:saml_app).reject { |participation| participation.saml_app_id == except&.id || participation.saml_app.slo_url.blank? }
      record, token = OneTimeToken.issue!(subject: session, purpose: :saml_logout, replace: false, data: { "pending" => pending.map(&:id), "origin" => origin })
      [ record, token ]
    end

    def continue_chain(chain, token: nil)
      record, token = chain.is_a?(Array) ? chain : [ chain, token ]
      pending = record.data["pending"]
      participation = BrowserSessionApp.includes(:saml_app).find_by(id: pending.shift)
      record.update!(data: record.data.merge("pending" => pending))

      if participation
        return Messages.redirect_url(
          participation.saml_app.slo_url, type: "SAMLRequest", xml: logout_request_xml(participation), relay_state: token, certificate: certificate
        )
      end

      record.consume!
      finish(record.data["origin"])
    end

    def finish(origin)
      return origin["url"] if origin["type"] == "url"

      app = @project.saml_apps.find_by(id: origin["app_id"])
      return Oidc::Urls.hosted_page(@project, "signed-out") if app&.slo_url.blank?

      Messages.redirect_url(app.slo_url, type: "SAMLResponse", xml: logout_response_xml(app, origin["request_id"]), relay_state: origin["relay_state"], certificate: certificate)
    end

    # The cookie identifies the session; without it (another browser tab, a blocked cookie), the
    # app's NameID and SessionIndex do.
    def session_for(session_token, app, request)
      if session_token.present?
        session = BrowserSession.active.find_by(project: @project, token_digest: BrowserSession.digest(session_token))
        return session if session
      end

      session_index = request.at_xpath("samlp:SessionIndex", Messages::NAMESPACES)&.text.to_s.strip
      name_id = request.at_xpath("saml:NameID", Messages::NAMESPACES)&.text.to_s.strip
      return nil if session_index.blank?

      BrowserSessionApp.joins(:browser_session).merge(BrowserSession.active)
        .find_by(saml_app: app, session_index: session_index, name_id: name_id)&.browser_session
    end

    def end_session(session)
      session.revoke!
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
        .record(action: "end_user.signed_out", actor: session.end_user, target: session.end_user, metadata: { sso: true, protocol: "saml" })
    end

    def signature_valid?(app, binding, raw_query, xml)
      certificate = app.certificate
      return !app.require_signed_requests unless certificate

      binding == :redirect ? Messages.redirect_signature_valid?(raw_query, type: "SAMLRequest", certificate: certificate) : Messages.embedded_signature_valid?(xml, certificate)
    end

    def logout_request_xml(participation)
      app = participation.saml_app
      %(<samlp:LogoutRequest xmlns:samlp="#{Messages::PROTOCOL}" xmlns:saml="#{Messages::ASSERTION}" ID="#{Messages.new_id}" Version="2.0" ) +
        %(IssueInstant="#{Messages.timestamp(Time.current)}" Destination="#{escape(app.slo_url)}">) +
        %(<saml:Issuer>#{escape(issuer)}</saml:Issuer><saml:NameID Format="#{app.name_id_format_uri}">#{escape(participation.name_id)}</saml:NameID>) +
        %(<samlp:SessionIndex>#{escape(participation.session_index)}</samlp:SessionIndex></samlp:LogoutRequest>)
    end

    def logout_response_xml(app, request_id)
      in_response_to = request_id ? %( InResponseTo="#{escape(request_id)}") : ""
      %(<samlp:LogoutResponse xmlns:samlp="#{Messages::PROTOCOL}" xmlns:saml="#{Messages::ASSERTION}" ID="#{Messages.new_id}" Version="2.0" ) +
        %(IssueInstant="#{Messages.timestamp(Time.current)}" Destination="#{escape(app.slo_url)}"#{in_response_to}>) +
        %(<saml:Issuer>#{escape(issuer)}</saml:Issuer><samlp:Status><samlp:StatusCode Value="#{SUCCESS}"/></samlp:Status></samlp:LogoutResponse>)
    end

    def issuer
      Metadata.new(@project).entity_id
    end

    def certificate
      @certificate ||= SamlCertificate.active_for!(@project)
    end

    def error_page(description)
      Oidc::Urls.hosted_page(@project, "error", error: "invalid_request", error_description: description)
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
