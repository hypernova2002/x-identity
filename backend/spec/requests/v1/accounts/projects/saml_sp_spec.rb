require "rails_helper"
require "openapi_helper"

# A second project plays the customer's identity provider, using x-identity's own SAML IdP, which
# is itself checked against ruby-saml in saml_spec.rb.
RSpec.describe "SAML upstream identity providers", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:redirect_uri) { "https://shop.example.com/callback" }
  let(:app_client) { create(:app_client, project: project, redirect_uris: [ redirect_uri ]) }
  let(:idp_project) { create(:project) }
  let!(:idp_user) { create(:end_user, project: idp_project, email: "jane@acme.com", name: "Jane Acme") }
  let(:provider) do
    create(
      :identity_provider, :saml, project: project, create_users: true,
      saml_idp_entity_id: SamlIdp::Metadata.new(idp_project).entity_id, saml_sso_url: SamlIdp::Metadata.new(idp_project).sso_url,
      saml_slo_url: SamlIdp::Metadata.new(idp_project).slo_url,
      saml_idp_certificates: [ SamlCertificate.active_for!(idp_project).certificate ],
      saml_name_attribute: "displayName", saml_groups_attribute: "groups"
    )
  end
  let(:verifier_and_challenge) { pkce_pair }
  let(:hosted_base) { "#{Rails.configuration.x.console_base_url}/auth/#{project.account.slug}/#{project.uid}" }

  before { host! URI.parse(Rails.configuration.x.app_base_url).then { |uri| "#{uri.host}:#{uri.port}" } }

  def issuer_path(path, of: project)
    "#{URI.parse(of.token_issuer).path}/#{path}"
  end

  def query_of(url)
    Rack::Utils.parse_query(URI.parse(url).query)
  end

  # The customer's IdP answering as x-identity's own SAML IdP would.
  def idp_response(in_response_to:, user: idp_user, session_index: "_idp-session-1")
    idp_app = idp_project.saml_apps.find_or_create_by!(entity_id: provider.sp_entity_id) do |app|
      app.name = "Shop"
      app.acs_urls = [ provider.acs_url ]
      app.attribute_mappings = [ { "name" => "displayName", "source" => "name" }, { "name" => "groups", "source" => "groups" } ]
    end
    SamlIdp::ResponseBuilder.new(idp_app).success(
      end_user: user, acs_url: provider.acs_url, in_response_to: in_response_to, session_index: session_index,
      authenticated_at: Time.current, amr: [ "pwd" ]
    )
  end

  # Starts a hosted sign-in and sends the browser to the provider; returns the AuthnRequest's ID and RelayState.
  def start_hosted_sign_in
    get issuer_path("oauth2/authorize"), params: {
      response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid",
      state: "app-state", code_challenge: verifier_and_challenge.last, code_challenge_method: "S256"
    }
    interaction = query_of(response.location)["interaction"]
    get issuer_path("oauth2/interactions/#{interaction}/providers/#{provider.uid}")
    authn_request_from(response.location)
  end

  def authn_request_from(url)
    query = query_of(url)
    document, = SamlIdp::Messages.decode(query["SAMLRequest"], deflated: true)
    { id: document.root["ID"], relay_state: query["RelayState"], document: document, url: url }
  end

  def post_to_acs(saml_response, relay_state)
    post issuer_path("saml/sp/#{provider.uid}/acs"), params: { SAMLResponse: saml_response, RelayState: relay_state }.compact
    expect(response).to have_http_status(:see_other)
    response.location
  end

  def follow(url)
    get URI.parse(url).request_uri
    response.location
  end

  describe "service provider metadata" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml/sp/{provider_uid}/metadata" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :provider_uid, in: :path, required: true, schema: { type: :string }

      get "Service provider metadata for an upstream SAML provider" do
        tags "SAML"
        produces "application/xml"

        response 200, "metadata XML to import into the customer's identity provider"
      end
    end

    it "describes the ACS and logout URLs, signed requests, and the signing certificate" do
      get issuer_path("saml/sp/#{provider.uid}/metadata")

      document = Nokogiri::XML(response.body)
      namespaces = SamlIdp::Messages::NAMESPACES
      expect(document.root["entityID"]).to eq(provider.sp_entity_id)
      expect(document.at_xpath("//md:AssertionConsumerService", namespaces)["Location"]).to eq(provider.acs_url)
      expect(document.at_xpath("//md:SPSSODescriptor", namespaces)["AuthnRequestsSigned"]).to eq("true")
    end
  end

  describe "signing in on the hosted page" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml/sp/{provider_uid}/acs" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :provider_uid, in: :path, required: true, schema: { type: :string }

      post "Assertion consumer service for an upstream SAML identity provider" do
        tags "SAML"
        description "The provider posts the user's browser here with its SAML response (HTTP-POST binding)."
        request_body required: true, content: {
          "application/x-www-form-urlencoded" => {
            schema: {
              type: :object,
              required: %w[SAMLResponse],
              properties: {
                SAMLResponse: { type: :string, description: "The provider's base64-encoded response." },
                RelayState: { type: :string, description: "From the AuthnRequest; absent for IdP-initiated sign-in." }
              }
            }
          }
        }

        response 303, "on to finish the sign-in, or to the hosted error page"
      end
    end

    it "sends a signed AuthnRequest, then signs in and creates the user from the response" do
      request = start_hosted_sign_in
      expect(request[:url]).to start_with(provider.saml_sso_url)
      expect(request[:document].at_xpath("//saml:Issuer", SamlIdp::Messages::NAMESPACES).text).to eq(provider.sp_entity_id)
      raw_query = URI.parse(request[:url]).query
      expect(SamlIdp::Messages.redirect_signature_valid?(raw_query, type: "SAMLRequest", certificate: SamlCertificate.active_for!(project).x509)).to be(true)

      resume = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])
      expect(resume).to include("/oauth2/authorize/resume?ticket=")

      expect(query_of(follow(resume))).to include("state" => "app-state")
      end_user = project.end_users.find_by!(email: "jane@acme.com")
      expect(end_user).to have_attributes(name: "Jane Acme", email_verified_at: be_present)
      expect(end_user.identities.sole).to have_attributes(identity_provider: provider, subject: "jane@acme.com")
      expect(BrowserSession.sole).to have_attributes(identity_provider: provider, upstream_name_id: "jane@acme.com", upstream_session_index: "_idp-session-1")
    end

    it "returns to the hosted page with the error when the provider was disabled meanwhile" do
      request = start_hosted_sign_in
      provider.update!(enabled: false)

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(location).to start_with("#{hosted_base}/login?")
      expect(query_of(location)).to include("error" => "invalid_state")
    end

    it "shows the hosted error page when the sign-in ended while the user was at the provider" do
      request = start_hosted_sign_in
      OneTimeToken.find_by!(purpose: "oidc_interaction").consume!

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(location).to start_with("#{hosted_base}/error?")
    end

    it "refuses a response whose request was answered at the same moment by another" do
      request = start_hosted_sign_in
      allow(OneTimeToken).to receive(:find_usable).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap { |record| allow(record).to receive(:consume!).and_return(false) if record }
      end

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(query_of(location)).to include("error" => "invalid_state")
      expect(project.end_users.where(email: "jane@acme.com")).to be_empty
    end

    it "only trusts emails at the provider's domains" do
      outsider = create(:end_user, project: idp_project, email: "mallory@elsewhere.com")
      request = start_hosted_sign_in

      location = post_to_acs(idp_response(in_response_to: request[:id], user: outsider), request[:relay_state])

      expect(query_of(location)).to include("error" => "provider_email_unverified")
      expect(project.end_users.where(email: "mallory@elsewhere.com")).to be_empty
    end

    it "refuses responses to another request" do
      request = start_hosted_sign_in
      body = { SAMLResponse: idp_response(in_response_to: "_someone-elses-request"), RelayState: request[:relay_state] }

      assert_api_response :post, 303, body: body, path_params: project_path_params(project, provider_uid: provider.uid)

      expect(query_of(response.location)).to include("error" => "invalid_saml_response")
    end

    it "refuses responses signed by another key" do
      provider.update!(saml_idp_certificates: [ SamlCertificate.generate!(project: create(:project), status: "active").certificate ])
      request = start_hosted_sign_in

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(query_of(location)).to include("error" => "invalid_saml_response")
    end

    it "doesn't create users when neither the provider nor the project allows it" do
      provider.update!(create_users: false)
      project.update!(allow_self_sign_up: false)
      request = start_hosted_sign_in

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(query_of(location)).to include("error" => "sign_up_disabled")
    end

    it "keeps mapped group memberships in step with the provider" do
      engineering = create(:group, project: project, name: "Engineering")
      sales = create(:group, project: project, name: "Sales")
      provider.group_mappings.create!(value: "acme-engineering", group: engineering)
      provider.group_mappings.create!(value: "acme-sales", group: sales)
      idp_project.groups.create!(name: "acme-engineering").group_memberships.create!(end_user: idp_user)

      request = start_hosted_sign_in
      follow(post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state]))

      groups = project.end_users.find_by!(email: "jane@acme.com").groups.pluck(:name)
      expect(groups).to include("Engineering")
      expect(groups).not_to include("Sales")
    end
  end

  describe "the API redirect flow" do
    it "works with SAML providers too" do
      get issuer_path("auth/providers/#{provider.uid}/authorize"), params: {
        client_id: app_client.uid, redirect_uri: redirect_uri, state: "s", code_challenge: verifier_and_challenge.last, code_challenge_method: "S256"
      }
      request = authn_request_from(response.location)

      location = post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state])

      expect(location).to start_with(redirect_uri)
      expect(query_of(location)).to have_key("code")
    end
  end

  describe "IdP-initiated sign-in" do
    it "is refused unless the provider allows it" do
      location = post_to_acs(idp_response(in_response_to: nil), nil)

      expect(location).to start_with("#{hosted_base}/error?")
    end

    it "signs in to the app portal, once per assertion" do
      provider.update!(allow_idp_initiated: true)
      saml_response = idp_response(in_response_to: nil)

      resume = post_to_acs(saml_response, nil)
      expect(follow(resume)).to eq("#{hosted_base}/apps")

      replayed = post_to_acs(saml_response, nil)
      expect(replayed).to include("error=invalid_saml_response")
    end
  end

  describe "home realm discovery" do
    it "finds the provider for an email's domain" do
      provider
      get issuer_path("oauth2/authorize"), params: {
        response_type: "code", client_id: app_client.uid, redirect_uri: redirect_uri, scope: "openid",
        code_challenge: verifier_and_challenge.last, code_challenge_method: "S256"
      }
      interaction = query_of(response.location)["interaction"]

      post issuer_path("oauth2/interactions/#{interaction}/discover"), params: { email: "Jane@Acme.com" }, as: :json
      expect(response.parsed_body).to eq("identity_provider_uid" => provider.uid)

      post issuer_path("oauth2/interactions/#{interaction}/discover"), params: { email: "casey@shop.test" }, as: :json
      expect(response.parsed_body).to eq("identity_provider_uid" => nil)

      get issuer_path("oauth2/interactions/#{interaction}")
      expect(response.parsed_body).to include("home_realm_discovery" => true, "identity_providers" => [])
    end
  end

  describe "single logout with the provider" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml/sp/{provider_uid}/slo" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :provider_uid, in: :path, required: true, schema: { type: :string }

      get "Single logout with an upstream SAML identity provider (HTTP-Redirect binding)" do
        tags "SAML"
        description "The provider sends its LogoutRequests here, and its LogoutResponses to ours. Messages must be signed by the provider."
        %w[SAMLRequest SAMLResponse RelayState SigAlg Signature].each { |name| parameter name: name.to_sym, in: :query, schema: { type: :string } }

        response 303, "back to the provider with a LogoutResponse, or on to the hosted signed-out page"
      end

      post "Single logout with an upstream SAML identity provider (HTTP-POST binding)" do
        tags "SAML"
        request_body required: true, content: {
          "application/x-www-form-urlencoded" => {
            schema: {
              type: :object,
              properties: {
                SAMLRequest: { type: :string, description: "Base64-encoded, not deflated." },
                SAMLResponse: { type: :string, description: "Base64-encoded, not deflated." },
                RelayState: { type: :string }
              }
            }
          }
        }

        response 303, "back to the provider with a LogoutResponse, or on to the hosted signed-out page"
      end
    end

    before do
      request = start_hosted_sign_in
      follow(post_to_acs(idp_response(in_response_to: request[:id]), request[:relay_state]))
    end

    it "logs out at the provider after hosted logout" do
      get issuer_path("oauth2/logout")

      expect(response.location).to start_with(provider.saml_slo_url)
      logout_request = authn_request_from(response.location)
      expect(logout_request[:document].at_xpath("//saml:NameID", SamlIdp::Messages::NAMESPACES).text).to eq("jane@acme.com")

      idp_reply = SamlIdp::Messages.redirect_url(
        provider.sp_slo_url, type: "SAMLResponse", relay_state: logout_request[:relay_state], certificate: SamlCertificate.active_for!(idp_project),
        xml: %(<samlp:LogoutResponse xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" ID="_r" Version="2.0" IssueInstant="#{Time.current.utc.iso8601}"/>)
      )
      get URI.parse(idp_reply).request_uri

      expect(response.location).to eq("#{hosted_base}/signed-out")
    end

    it "ends the session when the provider asks, and answers it" do
      xml = %(<samlp:LogoutRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" xmlns:saml="#{SamlIdp::Messages::ASSERTION}" ID="_idp-logout" ) +
        %(Version="2.0" IssueInstant="#{Time.current.utc.iso8601}"><saml:Issuer>#{provider.saml_idp_entity_id}</saml:Issuer>) +
        %(<saml:NameID>jane@acme.com</saml:NameID><samlp:SessionIndex>_idp-session-1</samlp:SessionIndex></samlp:LogoutRequest>)
      url = SamlIdp::Messages.redirect_url(provider.sp_slo_url, type: "SAMLRequest", xml: xml, relay_state: "idp-state", certificate: SamlCertificate.active_for!(idp_project))

      get URI.parse(url).request_uri

      expect(BrowserSession.sole.revoked_at).to be_present
      expect(response.location).to start_with(provider.saml_slo_url)
      reply, = SamlIdp::Messages.decode(query_of(response.location)["SAMLResponse"], deflated: true)
      expect(reply.root["InResponseTo"]).to eq("_idp-logout")
    end

    it "ignores logout requests that aren't signed by the provider" do
      xml = %(<samlp:LogoutRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" xmlns:saml="#{SamlIdp::Messages::ASSERTION}" ID="_x" ) +
        %(Version="2.0"><saml:Issuer>#{provider.saml_idp_entity_id}</saml:Issuer><saml:NameID>jane@acme.com</saml:NameID></samlp:LogoutRequest>)
      url = SamlIdp::Messages.redirect_url(provider.sp_slo_url, type: "SAMLRequest", xml: xml, relay_state: nil, certificate: SamlCertificate.active_for!(project))

      assert_api_response :get, 303, params: query_of(url).symbolize_keys, path_params: project_path_params(project, provider_uid: provider.uid)
      assert_api_response :post, 303, body: { SAMLRequest: Base64.strict_encode64(xml) }, path_params: project_path_params(project, provider_uid: provider.uid)

      expect(BrowserSession.sole.revoked_at).to be_nil
    end
  end

  describe "configuring a provider from its metadata" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/identity-providers/parse-saml-metadata" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Read an upstream SAML provider's metadata into settings" do
        tags "Identity providers"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: IdentityProviders::ParseSamlMetadataRequest.as_schema } }

        response 200, "the settings found; nothing is saved" do
          schema type: :object
        end
      end
    end

    it "reads the entity ID, endpoints and certificates" do
      admin = create(:user, :admin, account: project.account)

      assert_api_response(:post, 200, headers: auth_headers_for(admin), body: { metadata_xml: SamlIdp::Metadata.new(idp_project).to_xml },
        path_params: project_path_params(project)) do
        expect(parsed_body).to include(
          "saml_idp_entity_id" => SamlIdp::Metadata.new(idp_project).entity_id,
          "saml_sso_url" => SamlIdp::Metadata.new(idp_project).sso_url,
          "saml_idp_certificates" => [ SamlCertificate.active_for!(idp_project).certificate ]
        )
      end
    end
  end
end
