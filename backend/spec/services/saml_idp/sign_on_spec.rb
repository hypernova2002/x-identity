require "rails_helper"

RSpec.describe SamlIdp::SignOn do
  let(:project) { create(:project) }
  let(:endpoints) { ProjectEndpoints.new(project) }
  let(:sign_on) { described_class.new(project: project, endpoints: endpoints) }
  let(:app) { create(:saml_app, project: project) }

  def authn_request(issuer: app.entity_id, **attributes)
    attribute_xml = { ID: "_request-1", Version: "2.0", IssueInstant: Time.current.utc.iso8601 }.merge(attributes).map { |name, value| %( #{name}="#{value}") }.join
    issuer_xml = issuer ? %(<saml:Issuer xmlns:saml="#{SamlIdp::Messages::ASSERTION}">#{issuer}</saml:Issuer>) : ""
    %(<samlp:AuthnRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}"#{attribute_xml}>#{issuer_xml}</samlp:AuthnRequest>)
  end

  def post(xml)
    sign_on.sso(params: { "SAMLRequest" => Base64.strict_encode64(xml) }, raw_query: "", binding: :post, session_token: nil)
  end

  def error_description(outcome)
    expect(outcome.redirect_url).to start_with(endpoints.hosted_page("error"))
    Rack::Utils.parse_query(URI.parse(outcome.redirect_url).query)["error_description"]
  end

  it "refuses what isn't an AuthnRequest, and requests without an issuer" do
    expect(error_description(post(%(<samlp:LogoutRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}"/>)))).to eq("This isn't a SAML sign-in request.")
    expect(error_description(post(authn_request(issuer: nil)))).to include("The app (unnamed) isn't set up")
  end

  it "only answers with HTTP-POST" do
    outcome = post(authn_request(ProtocolBinding: SamlIdp::Messages::REDIRECT_BINDING))

    expect(error_description(outcome)).to include("asked for a response binding that isn't supported")
    expect(post(authn_request(ProtocolBinding: SamlIdp::Messages::POST_BINDING)).redirect_url).to start_with(endpoints.hosted_page("login"))
  end

  it "checks embedded signatures on POSTed requests from apps that require them" do
    app_keys = SamlCertificate.generate!(project: create(:project), status: "active")
    app.update!(sp_certificate: app_keys.certificate, require_signed_requests: true)

    expect(error_description(post(authn_request))).to include("isn't signed correctly")
    expect(post(SamlIdp::Messages.sign(authn_request, app_keys)).redirect_url).to start_with(endpoints.hosted_page("login"))
  end

  it "shows the error page when the signed-in user may not use the app" do
    restricted = create(:saml_app, project: project, assigned_to_everyone: false)
    session, = BrowserSession.start!(end_user: create(:end_user, project: project, in_all_end_users_group: false), amr: [ "pwd" ], authenticated_at: Time.current)

    outcome = sign_on.respond(restricted, { "acs_url" => restricted.default_acs_url }, session)

    expect(Rack::Utils.parse_query(URI.parse(outcome.redirect_url).query)).to include("error" => "app_access_denied")
  end
end
