require "rails_helper"
require "openapi_helper"

# The other side of every exchange is ruby-saml acting as the service provider, so responses are
# checked the way a real app checks them.
RSpec.describe "SAML identity provider", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:sp) { create(:saml_app, :with_slo, project: project) }
  let!(:end_user) { create(:end_user, project: project, email: "casey@shop.test") }
  let(:metadata) { SamlIdp::Metadata.new(project) }
  let(:hosted_base) { "#{Rails.configuration.x.console_base_url}/auth/#{project.account.slug}/#{project.uid}" }

  before do
    host! URI.parse(Rails.configuration.x.app_base_url).then { |uri| "#{uri.host}:#{uri.port}" }
    project.groups.find_by!(name: "All end users").update!(name: "All end users")
  end

  def issuer_path(path)
    "#{URI.parse(project.token_issuer).path}/#{path}"
  end

  def sp_settings(saml_app = sp)
    OneLogin::RubySaml::Settings.new.tap do |settings|
      settings.sp_entity_id = saml_app.entity_id
      settings.assertion_consumer_service_url = saml_app.acs_urls.first
      settings.single_logout_service_url = saml_app.slo_url
      settings.idp_entity_id = metadata.entity_id
      settings.idp_sso_service_url = metadata.sso_url
      settings.idp_slo_service_url = metadata.slo_url
      settings.idp_cert = SamlCertificate.active_for!(project).certificate
      settings.name_identifier_format = saml_app.name_id_format_uri
    end
  end

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  # Sends the browser to the IdP with an AuthnRequest, as the app would; returns the request's ID.
  def start_sign_in(saml_app = sp, settings: sp_settings(saml_app))
    request = OneLogin::RubySaml::Authrequest.new
    url = request.create(settings)
    get URI.parse(url).request_uri
    request.uuid
  end

  def sign_in_on_hosted_page(email: "casey@shop.test")
    interaction = query_of(response.location)["interaction"]
    post issuer_path("oauth2/interactions/#{interaction}/sign-in"), params: { email: email, password: "correct horse battery staple" }, as: :json
    response.parsed_body
  end

  def saml_response_from_form
    expect(response.media_type).to eq("text/html")
    Nokogiri::HTML(response.body).at_css("input[name=SAMLResponse]")["value"]
  end

  def follow_to_app(redirect_to)
    get URI.parse(redirect_to).request_uri
    saml_response_from_form
  end

  def signed_in_response(saml_app = sp, request_id: start_sign_in(saml_app))
    raw = follow_to_app(sign_in_on_hosted_page["redirect_to"])
    OneLogin::RubySaml::Response.new(raw, settings: sp_settings(saml_app), matches_request_id: request_id)
  end

  describe "metadata" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml/metadata" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "SAML identity provider metadata" do
        tags "SAML"
        produces "application/xml"

        response 200, "metadata XML"
      end
    end

    it "publishes the entity ID, endpoints and signing certificate" do
      get issuer_path("saml/metadata")

      document = Nokogiri::XML(response.body)
      namespaces = SamlIdp::Messages::NAMESPACES
      expect(document.root["entityID"]).to eq(metadata.entity_id)
      expect(document.at_xpath("//md:SingleSignOnService", namespaces)["Location"]).to eq(metadata.sso_url)
      expect(document.at_xpath("//ds:X509Certificate", namespaces).text).to eq(SamlCertificate.active_for!(project).base64_der)
    end

    it "is something ruby-saml can configure an app from" do
      get issuer_path("saml/metadata")

      settings = OneLogin::RubySaml::IdpMetadataParser.new.parse(response.body)
      expect(settings.idp_entity_id).to eq(metadata.entity_id)
    end
  end

  describe "SP-initiated sign-in" do
    it "sends the browser to hosted login, then posts a valid, signed response to the app" do
      request_id = start_sign_in
      expect(response.location).to start_with("#{hosted_base}/login?interaction=")

      saml_response = signed_in_response(request_id: request_id)

      expect(saml_response.is_valid?).to be(true), saml_response.errors.join(", ")
      expect(saml_response.nameid).to eq("casey@shop.test")
      expect(saml_response.attributes.multi("groups")).to eq([ "All end users" ])
      expect(saml_response.sessionindex).to eq(BrowserSessionApp.sole.session_index)
      expect(AuditEvent.where(action: "end_user.signed_in_to_app")).to exist
    end

    it "uses the persistent NameID when the app asks for it" do
      sp.update!(name_id_format: "persistent")

      expect(signed_in_response.nameid).to eq(end_user.uid)
    end

    it "can sign the whole response instead of the assertion" do
      sp.update!(sign_assertion: false, sign_response: true)

      saml_response = signed_in_response
      expect(saml_response.is_valid?).to be(true), saml_response.errors.join(", ")
    end

    it "signs in straight away with a single sign-on session" do
      signed_in_response
      other_app = create(:saml_app, project: project)

      request_id = start_sign_in(other_app)

      saml_response = OneLogin::RubySaml::Response.new(saml_response_from_form, settings: sp_settings(other_app), matches_request_id: request_id)
      expect(saml_response.is_valid?).to be(true), saml_response.errors.join(", ")
    end

    it "refuses users the app isn't assigned to" do
      unassigned = create(:saml_app, project: project, assigned_to_everyone: false)
      start_sign_in(unassigned)

      expect(sign_in_on_hosted_page.dig("error", "code")).to eq("app_access_denied")
    end

    it "answers IsPassive with NoPassive when there's no session" do
      settings = sp_settings
      settings.passive = true
      start_sign_in(settings: settings)

      saml_response = OneLogin::RubySaml::Response.new(saml_response_from_form, settings: settings)
      expect(saml_response.status_code).to include("Responder")
      expect(saml_response.response.to_s).to include("NoPassive")
    end

    it "shows unknown apps and unregistered ACS URLs on the hosted error page" do
      unknown = sp_settings.tap { |settings| settings.sp_entity_id = "https://unknown.example.com" }
      start_sign_in(settings: unknown)
      expect(response.location).to start_with("#{hosted_base}/error?")

      wrong_acs = sp_settings.tap { |settings| settings.assertion_consumer_service_url = "https://evil.example.com/acs" }
      start_sign_in(settings: wrong_acs)
      expect(response.location).to start_with("#{hosted_base}/error?")
    end

    describe "with signed requests required" do
      let(:sp_key) { OpenSSL::PKey::RSA.generate(2048) }
      let(:sp_certificate) do
        OpenSSL::X509::Certificate.new.tap do |certificate|
          certificate.version = 2
          certificate.serial = 1
          certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=sp")
          certificate.public_key = sp_key.public_key
          certificate.not_before = 1.hour.ago
          certificate.not_after = 1.year.from_now
          certificate.sign(sp_key, OpenSSL::Digest.new("SHA256"))
        end
      end

      before { sp.update!(sp_certificate: sp_certificate.to_pem, require_signed_requests: true) }

      it "refuses unsigned requests" do
        start_sign_in

        expect(response.location).to start_with("#{hosted_base}/error?")
      end

      it "accepts requests signed with the app's key" do
        settings = sp_settings
        settings.certificate = sp_certificate.to_pem
        settings.private_key = sp_key.to_pem
        settings.security[:authn_requests_signed] = true
        settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA256

        start_sign_in(settings: settings)

        expect(response.location).to start_with("#{hosted_base}/login?")
      end
    end
  end

  describe "IdP-initiated sign-in" do
    it "launches the app from an existing session, without InResponseTo" do
      signed_in_response
      sp.update!(default_relay_state: "/dashboard")

      get issuer_path("saml/apps/#{sp.uid}/launch")

      saml_response = OneLogin::RubySaml::Response.new(saml_response_from_form, settings: sp_settings)
      expect(saml_response.is_valid?).to be(true), saml_response.errors.join(", ")
      expect(Nokogiri::HTML(response.body).at_css("input[name=RelayState]")["value"]).to eq("/dashboard")
    end

    it "asks for a sign-in first when there's no session" do
      get issuer_path("saml/apps/#{sp.uid}/launch")

      expect(response.location).to start_with("#{hosted_base}/login?interaction=")
    end
  end

  describe "single logout" do
    let(:other_app) { create(:saml_app, :with_slo, project: project) }

    before do
      signed_in_response
      start_sign_in(other_app)
    end

    it "logs out of the other apps, then answers the app that asked" do
      settings = sp_settings
      settings.name_identifier_value = "casey@shop.test"
      settings.sessionindex = BrowserSessionApp.find_by!(saml_app: sp).session_index
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      get URI.parse(logout_request.create(settings)).request_uri

      expect(response.location).to start_with(other_app.slo_url)
      to_other_app = query_of(response.location)
      other_request = OneLogin::RubySaml::SloLogoutrequest.new(to_other_app["SAMLRequest"], settings: sp_settings(other_app))
      expect(other_request.name_id).to eq("casey@shop.test")
      expect(BrowserSession.sole.revoked_at).to be_present

      reply = OneLogin::RubySaml::SloLogoutresponse.new.create(sp_settings(other_app), other_request.id, nil, RelayState: to_other_app["RelayState"])
      get URI.parse(reply).request_uri

      expect(response.location).to start_with(sp.slo_url)
      final = OneLogin::RubySaml::Logoutresponse.new(query_of(response.location)["SAMLResponse"], sp_settings, matches_request_id: logout_request.uuid)
      expect(final.validate).to be(true), final.errors.join(", ")
    end

    it "logs out of SAML apps on OpenID Connect logout too" do
      get issuer_path("oauth2/logout")

      expect(response.location).to start_with(sp.slo_url).or start_with(other_app.slo_url)
    end
  end
end
