require "rails_helper"

# A second project plays the customer's identity provider, as in saml_sp_spec.rb.
RSpec.describe "SAML on a custom domain", type: :request do
  let(:project) { create(:project) }
  let!(:domain) { project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current) }
  let(:custom) { "https://login.acme.com" }
  let(:standard_host) { URI.parse(Rails.configuration.x.app_base_url).then { |uri| "#{uri.host}:#{uri.port}" } }
  let(:redirect_uri) { "https://shop.example.com/callback" }
  let(:app_client) { create(:app_client, project: project, redirect_uris: [ redirect_uri ]) }
  let(:idp_project) { create(:project) }
  let!(:idp_user) { create(:end_user, project: idp_project, email: "jane@acme.com") }
  let(:provider) do
    create(
      :identity_provider, :saml, project: project, create_users: true,
      saml_idp_entity_id: SamlIdp::Metadata.new(idp_project).entity_id, saml_sso_url: SamlIdp::Metadata.new(idp_project).sso_url,
      saml_idp_certificates: [ SamlCertificate.active_for!(idp_project).certificate ]
    )
  end
  let(:verifier_and_challenge) { pkce_pair }

  def on_custom_domain
    host! "login.acme.com"
    https!
  end

  def on_standard_urls
    host! standard_host
    https!(false)
  end

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  def idp_response(in_response_to:)
    idp_app = idp_project.saml_apps.find_or_create_by!(entity_id: provider.sp_entity_id) do |app|
      app.name = "Shop"
      app.acs_urls = [ provider.acs_url ]
    end
    SamlIdp::ResponseBuilder.new(idp_app).success(
      end_user: idp_user, acs_url: provider.acs_url, in_response_to: in_response_to, session_index: "_s1", authenticated_at: Time.current, amr: [ "pwd" ]
    )
  end

  # Posts the IdP's response to the provider's ACS URL, on whichever host that URL is.
  def post_to_acs(saml_response, relay_state)
    acs = URI.parse(provider.acs_url)
    acs.host == "login.acme.com" ? on_custom_domain : on_standard_urls
    post acs.path, params: { SAMLResponse: saml_response, RelayState: relay_state }.compact
    response.location
  end

  describe "a sign-in that starts on the custom domain and returns to a provider on the standard URLs" do
    it "hands the sign-in back to the custom domain, which creates the session there" do
      on_custom_domain
      get "/oauth2/authorize", params: {
        response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid",
        state: "s", code_challenge: verifier_and_challenge.last, code_challenge_method: "S256"
      }
      get "/oauth2/interactions/#{query_of(response.location)['interaction']}/providers/#{provider.uid}"
      authn_request = query_of(response.location)
      document, = SamlIdp::Messages.decode(authn_request["SAMLRequest"], deflated: true)
      expect(document.root["AssertionConsumerServiceURL"]).to start_with(project.token_issuer)

      resume = post_to_acs(idp_response(in_response_to: document.root["ID"]), authn_request["RelayState"])
      expect(resume).to start_with("#{custom}/oauth2/authorize/resume?ticket=")

      on_custom_domain
      get URI.parse(resume).request_uri
      expect(response.headers["Set-Cookie"]).to match(/path=\/;/i)
      expect(query_of(response.location)).to include("iss" => custom, "state" => "s")
    end
  end

  describe "a provider switched to the custom domain" do
    before { provider.update!(on_custom_domain: true, allow_idp_initiated: true) }

    it "uses the domain for its service provider URLs, and its unsolicited sign-ins stay there" do
      expect(provider).to have_attributes(sp_entity_id: "#{custom}/saml/sp/#{provider.uid}/metadata", acs_url: "#{custom}/saml/sp/#{provider.uid}/acs")

      resume = post_to_acs(idp_response(in_response_to: nil), nil)
      expect(resume).to start_with("#{custom}/oauth2/authorize/resume?ticket=")

      get URI.parse(resume).request_uri
      expect(response.location).to eq("#{custom}/apps")
    end
  end

  describe "SAML apps" do
    let(:saml_app) { create(:saml_app, project: project) }

    def assertion_issuer(app)
      xml = SamlIdp::ResponseBuilder.new(app).success(
        end_user: create(:end_user, project: project), acs_url: app.default_acs_url, in_response_to: nil, session_index: "_s", authenticated_at: Time.current, amr: [ "pwd" ]
      )
      document, = SamlIdp::Messages.decode(xml, deflated: false)
      document.at_xpath("/samlp:Response/saml:Issuer", SamlIdp::Messages::NAMESPACES).text
    end

    it "keep the standard entity ID until they're switched, whichever host they use" do
      expect(saml_app.on_custom_domain).to be(false)
      expect(assertion_issuer(saml_app)).to eq("#{project.token_issuer}/saml/metadata")

      saml_app.update!(on_custom_domain: true)
      expect(assertion_issuer(saml_app)).to eq("#{custom}/saml/metadata")
      expect(saml_app.launch_url).to eq("#{custom}/saml/apps/#{saml_app.uid}/launch")
    end

    it "publish the domain's metadata on the domain" do
      on_custom_domain
      get "/saml/metadata"

      expect(Nokogiri::XML(response.body).root["entityID"]).to eq("#{custom}/saml/metadata")
    end

    it "can only be switched while the project has a verified domain" do
      domain.update!(status: "pending")

      expect(saml_app.update(on_custom_domain: true)).to be(false)
      expect(saml_app.errors[:on_custom_domain]).to include("needs a verified custom domain")
    end

    it "start on the custom domain when created after it's verified, as do SAML providers" do
      owner = create(:user, :owner, account: project.account)
      created = SamlApps::Management.new(actor: owner, project: project).create(name: "Wiki", entity_id: "https://wiki.example.com", acs_urls: [ "https://wiki.example.com/acs" ])
      expect(created.on_custom_domain).to be(true)

      domain.destroy!
      later = SamlApps::Management.new(actor: owner, project: project.reload).create(name: "Docs", entity_id: "https://docs.example.com", acs_urls: [ "https://docs.example.com/acs" ])
      expect(later.on_custom_domain).to be(false)
      expect(created.reload.project_endpoints.issuer).to eq(project.token_issuer)
    end
  end
end
