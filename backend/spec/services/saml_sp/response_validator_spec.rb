require "rails_helper"

RSpec.describe SamlSp::ResponseValidator do
  let(:idp_project) { create(:project) }
  let(:idp_user) { create(:end_user, project: idp_project, email: "jane@acme.com", name: "Jane Acme") }
  let(:provider) do
    create(:identity_provider, :saml, saml_idp_entity_id: SamlIdp::Metadata.new(idp_project).entity_id,
      saml_idp_certificates: [ SamlCertificate.active_for!(idp_project).certificate ])
  end

  def response_from_idp(in_response_to:, name_id_format: "email", mappings: [ { "name" => "mail", "source" => "email" } ])
    app = idp_project.saml_apps.create!(name: "Shop", entity_id: provider.sp_entity_id, acs_urls: [ provider.acs_url ], name_id_format: name_id_format, attribute_mappings: mappings)
    SamlIdp::ResponseBuilder.new(app).success(end_user: idp_user, acs_url: provider.acs_url, in_response_to: in_response_to, session_index: "_s", authenticated_at: Time.current, amr: [ "pwd" ])
  end

  def reason(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.reason }
  end

  it "takes the email from the configured attribute, or from an email NameID" do
    provider.update!(saml_email_attribute: "mail")
    expect(described_class.new(provider).validate(response_from_idp(in_response_to: "_r1", name_id_format: "persistent"), request_id: "_r1"))
      .to include("email" => "jane@acme.com", "sub" => idp_user.uid, "email_verified" => true)
  end

  it "reads a blank attribute as missing" do
    provider.update!(saml_name_attribute: "displayName")
    idp_user.update!(name: nil)

    claims = described_class.new(provider).validate(response_from_idp(in_response_to: "_r1", mappings: [ { "name" => "displayName", "source" => "name" } ]), request_id: "_r1")

    expect(claims["name"]).to be_nil
  end

  it "has no email when the NameID isn't one and no attribute is set" do
    claims = described_class.new(provider).validate(response_from_idp(in_response_to: "_r1", name_id_format: "persistent", mappings: []), request_id: "_r1")

    expect(claims).to include("email" => nil, "email_verified" => false)
  end

  it "refuses an unsolicited response that claims to answer a request" do
    expect(reason { described_class.new(provider).validate(response_from_idp(in_response_to: "_r1"), request_id: nil) }).to eq(:saml_response_unrequested)
  end

  it "refuses transient NameIDs, which can't identify the user next time" do
    saml_response = response_from_idp(in_response_to: "_r1")
    allow_any_instance_of(OneLogin::RubySaml::Response).to receive(:name_id_format).and_return(described_class::TRANSIENT)

    expect(reason { described_class.new(provider).validate(saml_response, request_id: "_r1") }).to eq(:saml_response_transient_name_id)
  end

  it "refuses what it can't read, and an empty response as invalid" do
    [ Base64.strict_encode64("<samlp:Response"), "%%%" ].each do |unreadable|
      expect(reason { described_class.new(provider).validate(unreadable, request_id: "_r1") }).to eq(:saml_response_unreadable)
    end
    expect(reason { described_class.new(provider).validate("", request_id: "_r1") }).to eq(:saml_response_not_valid)
  end
end
