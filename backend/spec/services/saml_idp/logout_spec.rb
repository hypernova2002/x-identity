require "rails_helper"

RSpec.describe SamlIdp::Logout do
  let(:project) { create(:project) }
  let(:endpoints) { ProjectEndpoints.new(project) }
  let(:logout) { described_class.new(project: project, endpoints: endpoints, ip: "203.0.113.10") }
  let(:app) { create(:saml_app, :with_slo, project: project) }
  let(:other_app) { create(:saml_app, :with_slo, project: project) }
  let(:end_user) { create(:end_user, project: project, email: "casey@shop.test") }
  let(:signed_out) { endpoints.hosted_page("signed-out") }

  # A key pair for whoever signs the messages sent to us: an app, or an upstream provider.
  def keys
    SamlCertificate.generate!(project: create(:project), status: "active")
  end

  # A nil issuer or name_id leaves its element out.
  def logout_request(issuer:, name_id: "casey@shop.test", session_index: nil, id: "_request-1")
    issuer_xml = issuer ? "<saml:Issuer>#{issuer}</saml:Issuer>" : ""
    name_id_xml = name_id ? "<saml:NameID>#{name_id}</saml:NameID>" : ""
    index = session_index ? "<samlp:SessionIndex>#{session_index}</samlp:SessionIndex>" : ""
    id_attribute = id ? %( ID="#{id}") : ""
    %(<samlp:LogoutRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" xmlns:saml="#{SamlIdp::Messages::ASSERTION}"#{id_attribute} Version="2.0" ) +
      %(IssueInstant="#{Time.current.utc.iso8601}">#{issuer_xml}#{name_id_xml}#{index}</samlp:LogoutRequest>)
  end

  # The params and raw query a request arrives with, for either binding.
  def arriving(xml, binding:, signed_with: nil, relay_state: nil)
    if binding == :redirect
      url = if signed_with
        SamlIdp::Messages.redirect_url("https://idp.test/slo", type: "SAMLRequest", xml: xml, relay_state: relay_state, certificate: signed_with)
      else
        "https://idp.test/slo?#{{ SAMLRequest: Base64.strict_encode64(SamlIdp::Messages.deflate(xml)), RelayState: relay_state }.compact.to_query}"
      end
      raw_query = URI.parse(url).query
      [ Rack::Utils.parse_query(raw_query), raw_query ]
    else
      body = signed_with ? SamlIdp::Messages.sign(xml, signed_with) : xml
      [ { "SAMLRequest" => Base64.strict_encode64(body), "RelayState" => relay_state }.compact, "" ]
    end
  end

  def request_from_app(xml, binding: :post, signed_with: nil, relay_state: nil, session_token: nil)
    params, raw_query = arriving(xml, binding: binding, signed_with: signed_with, relay_state: relay_state)
    logout.receive(params: params, raw_query: raw_query, binding: binding, session_token: session_token)
  end

  def request_from_provider(provider, xml, signed_with:, binding: :post, session_token: nil)
    params, raw_query = arriving(xml, binding: binding, signed_with: signed_with)
    logout.receive_upstream(provider: provider, params: params, raw_query: raw_query, binding: binding, session_token: session_token)
  end

  def sign_in(apps: [ app ], upstream: nil)
    session, token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current, upstream: upstream)
    apps.each_with_index { |saml_app, index| session.browser_session_apps.create!(saml_app: saml_app, name_id: "casey@shop.test", session_index: "_index-#{index}") }
    [ session, token ]
  end

  # The message a redirect sends, parsed.
  def message_in(url, type)
    SamlIdp::Messages.decode(Rack::Utils.parse_query(URI.parse(url).query)[type], deflated: true).first
  end

  def error_description(url)
    expect(url).to start_with(endpoints.hosted_page("error"))
    Rack::Utils.parse_query(URI.parse(url).query)["error_description"]
  end

  def next_relay_state(url)
    Rack::Utils.parse_query(URI.parse(url).query)["RelayState"]
  end

  describe "a LogoutRequest from an app" do
    it "refuses what isn't a LogoutRequest from an app set up here" do
      authn_request = %(<samlp:AuthnRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" ID="_a" Version="2.0"/>)

      expect(error_description(request_from_app(authn_request))).to eq("This isn't a SAML logout request.")
      expect(error_description(request_from_app(logout_request(issuer: "https://unknown.example.com")))).to include("isn't set up for SAML")
      expect(error_description(request_from_app(logout_request(issuer: nil)))).to include("isn't set up for SAML")
      expect(error_description(logout.receive(params: { "SAMLRequest" => Base64.strict_encode64("<not xml") }, raw_query: "", binding: :post, session_token: nil)))
        .to eq("The SAML message isn't valid XML.")
      expect(error_description(logout.receive(params: {}, raw_query: "", binding: :post, session_token: nil))).to eq("The SAML message is missing.")
    end

    it "checks the signature of an app with a certificate, in either binding" do
      app_keys = keys
      app.update!(sp_certificate: app_keys.certificate)
      xml = logout_request(issuer: app.entity_id)

      expect(error_description(request_from_app(xml))).to include("isn't signed correctly")
      expect(error_description(request_from_app(xml, signed_with: keys))).to include("isn't signed correctly")
      expect(error_description(request_from_app(xml, binding: :redirect))).to include("isn't signed correctly")
      expect(request_from_app(xml, signed_with: app_keys)).to start_with(app.slo_url)
      expect(request_from_app(xml, binding: :redirect, signed_with: app_keys)).to start_with(app.slo_url)
    end

    it "answers at once when the browser has no session, returning the RelayState" do
      response_url = request_from_app(logout_request(issuer: app.entity_id), relay_state: "app-state")

      expect(response_url).to start_with(app.slo_url)
      expect(next_relay_state(response_url)).to eq("app-state")
      response = message_in(response_url, "SAMLResponse")
      expect(response.root["InResponseTo"]).to eq("_request-1")
      expect(response.at_xpath("//samlp:StatusCode", SamlIdp::Messages::NAMESPACES)["Value"]).to eq(described_class::SUCCESS)
    end

    it "sends an app without a logout URL to the signed-out page" do
      without_slo = create(:saml_app, project: project)

      expect(request_from_app(logout_request(issuer: without_slo.entity_id))).to eq(signed_out)
    end

    it "ends the cookie's session, logs out of the other apps one at a time, then answers the app that asked" do
      third_app = create(:saml_app, project: project)
      session, token = sign_in(apps: [ app, other_app, third_app ])

      to_other_app = request_from_app(logout_request(issuer: app.entity_id, id: "_from-app"), session_token: token)

      expect(session.reload.revoked_at).to be_present
      expect(AuditEvent.last).to have_attributes(action: "end_user.signed_out", metadata: { "sso" => true, "protocol" => "saml" })
      expect(to_other_app).to start_with(other_app.slo_url)
      expect(message_in(to_other_app, "SAMLRequest").at_xpath("//samlp:SessionIndex", SamlIdp::Messages::NAMESPACES).text).to eq("_index-1")

      back_to_app = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_other_app) }, raw_query: "", binding: :redirect, session_token: nil)
      expect(back_to_app).to start_with(app.slo_url)
      expect(message_in(back_to_app, "SAMLResponse").root["InResponseTo"]).to eq("_from-app")
    end

    it "finds the session from the app's NameID and SessionIndex without the cookie" do
      session, = sign_in(apps: [ app, other_app ])

      expect(request_from_app(logout_request(issuer: app.entity_id, name_id: "someone-else", session_index: "_index-0"))).to start_with(app.slo_url)
      expect(session.reload.revoked_at).to be_nil

      expect(request_from_app(logout_request(issuer: app.entity_id, session_index: "_index-0"), session_token: "stale-cookie")).to start_with(other_app.slo_url)
      expect(session.reload.revoked_at).to be_present
    end

    it "doesn't find an ended session, or one without a SessionIndex or NameID" do
      session, = sign_in(apps: [ app, other_app ])

      expect(request_from_app(logout_request(issuer: app.entity_id))).to start_with(app.slo_url)
      expect(request_from_app(logout_request(issuer: app.entity_id, name_id: nil, session_index: "_index-0"))).to start_with(app.slo_url)
      session.revoke!
      expect(request_from_app(logout_request(issuer: app.entity_id, session_index: "_index-0"))).to start_with(app.slo_url)
      expect(AuditEvent.where(action: "end_user.signed_out")).to be_empty
    end

    it "ends at the signed-out page when the app that asked was deleted meanwhile" do
      _session, token = sign_in(apps: [ app, other_app ])
      to_other_app = request_from_app(logout_request(issuer: app.entity_id), session_token: token)
      app.destroy!

      finished = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_other_app) }, raw_query: "", binding: :redirect, session_token: nil)

      expect(finished).to eq(signed_out)
    end

    it "answers a request without an ID without InResponseTo" do
      response_url = request_from_app(logout_request(issuer: app.entity_id, id: nil))

      expect(message_in(response_url, "SAMLResponse").root["InResponseTo"]).to be_nil
    end
  end

  describe "logging out from the console or OpenID Connect" do
    it "goes to the final URL once every app with a logout URL has answered" do
      session, = sign_in(apps: [ app ])

      to_app = logout.start(session, final_url: "https://shop.example.com/bye")
      expect(to_app).to start_with(app.slo_url)

      finished = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_app) }, raw_query: "", binding: :redirect, session_token: nil)
      expect(finished).to eq("https://shop.example.com/bye")
    end

    it "sends a response with an unknown or used RelayState to the signed-out page" do
      expect(logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => "unknown" }, raw_query: "", binding: :redirect, session_token: nil)).to eq(signed_out)
      expect(logout.receive(params: { "SAMLResponse" => "ok" }, raw_query: "", binding: :redirect, session_token: nil)).to eq(signed_out)
    end
  end

  describe "upstream SAML providers" do
    let(:provider_keys) { keys }
    let(:provider) do
      create(:identity_provider, :saml, project: project, saml_idp_certificates: [ provider_keys.certificate ], saml_slo_url: "https://idp.acme.com/saml/slo")
    end
    let(:upstream) { { "identity_provider_id" => provider.id, "name_id" => "casey@acme.com", "session_index" => "_upstream-1" } }

    def provider_request(**options)
      logout_request(issuer: provider.saml_idp_entity_id, name_id: "casey@acme.com", **options)
    end

    it "logs out at the provider last, without a Format when the session has none" do
      session, = sign_in(apps: [], upstream: upstream)

      to_provider = logout.start(session, final_url: "https://shop.example.com/bye")

      expect(to_provider).to start_with(provider.saml_slo_url)
      request = message_in(to_provider, "SAMLRequest")
      expect(request.at_xpath("//saml:NameID", SamlIdp::Messages::NAMESPACES)).to have_attributes(text: "casey@acme.com")
      expect(request.at_xpath("//saml:NameID", SamlIdp::Messages::NAMESPACES)["Format"]).to be_nil
      expect(request.at_xpath("//samlp:SessionIndex", SamlIdp::Messages::NAMESPACES).text).to eq("_upstream-1")

      finished = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_provider) }, raw_query: "", binding: :redirect, session_token: nil)
      expect(finished).to eq("https://shop.example.com/bye")
    end

    it "leaves out the SessionIndex when the upstream session has none" do
      session, = sign_in(apps: [], upstream: upstream.except("session_index"))

      request = message_in(logout.start(session, final_url: "https://shop.example.com/bye"), "SAMLRequest")

      expect(request.at_xpath("//samlp:SessionIndex", SamlIdp::Messages::NAMESPACES)).to be_nil
    end

    it "ends at the signed-out page when the provider was deleted meanwhile" do
      _session, token = sign_in(apps: [ app ], upstream: upstream)
      to_app = request_from_provider(provider, provider_request, signed_with: provider_keys, session_token: token)
      provider.destroy!

      finished = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_app) }, raw_query: "", binding: :redirect, session_token: nil)

      expect(finished).to eq(signed_out)
    end

    it "refuses requests that aren't LogoutRequests from the provider, or aren't signed by it" do
      expect(error_description(request_from_provider(provider, logout_request(issuer: "https://other-idp.example.com"), signed_with: provider_keys)))
        .to include("isn't a logout request from #{provider.name}")
      expect(error_description(request_from_provider(provider, %(<samlp:AuthnRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" ID="_a"/>), signed_with: provider_keys)))
        .to include("isn't a logout request")
      expect(error_description(request_from_provider(provider, provider_request, signed_with: keys))).to include("isn't signed correctly")
      expect(error_description(logout.receive_upstream(provider: provider, params: { "SAMLRequest" => "%%%" }, raw_query: "", binding: :redirect, session_token: nil)))
        .to be_present
    end

    it "ends every session for the NameID, narrowed to the SessionIndexes sent, then answers the provider" do
      first, = sign_in(apps: [], upstream: upstream)
      second, second_token = sign_in(apps: [ app ], upstream: upstream.merge("session_index" => "_upstream-2"))

      to_app = request_from_provider(provider, provider_request(session_index: "_upstream-2"), signed_with: provider_keys, session_token: second_token)

      expect([ first.reload.revoked_at, second.reload.revoked_at.present? ]).to eq([ nil, true ])
      expect(to_app).to start_with(app.slo_url)
      answer = logout.receive(params: { "SAMLResponse" => "ok", "RelayState" => next_relay_state(to_app) }, raw_query: "", binding: :redirect, session_token: nil)
      expect(answer).to start_with(provider.saml_slo_url)
      expect(message_in(answer, "SAMLResponse").root["InResponseTo"]).to eq("_request-1")
    end

    it "ends all of the NameID's sessions without SessionIndexes, and answers in the Redirect binding too" do
      sessions = Array.new(2) { sign_in(apps: [], upstream: upstream).first }

      answer = request_from_provider(provider, provider_request, signed_with: provider_keys, binding: :redirect)

      expect(sessions.map { |session| session.reload.revoked_at.present? }).to eq([ true, true ])
      expect(answer).to start_with(provider.saml_slo_url)
    end

    it "answers at once when no session matches, or the request has no NameID" do
      session, = sign_in(apps: [], upstream: upstream)

      expect(request_from_provider(provider, provider_request(session_index: "_unknown"), signed_with: provider_keys)).to start_with(provider.saml_slo_url)
      expect(request_from_provider(provider, logout_request(issuer: provider.saml_idp_entity_id, name_id: ""), signed_with: provider_keys))
        .to start_with(provider.saml_slo_url)
      expect(request_from_provider(provider, logout_request(issuer: provider.saml_idp_entity_id, name_id: nil), signed_with: provider_keys))
        .to start_with(provider.saml_slo_url)
      expect(session.reload.revoked_at).to be_nil
    end

    it "sends the browser to the signed-out page when the provider has no logout URL" do
      provider.update!(saml_slo_url: nil)

      expect(request_from_provider(provider, provider_request, signed_with: provider_keys)).to eq(signed_out)
    end
  end
end
