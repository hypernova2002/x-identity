require "rails_helper"

RSpec.describe SamlIdp::ResponseBuilder do
  let(:project) { create(:project) }
  let(:end_user) { create(:end_user, project: project, email: "casey@shop.test", name: nil, custom_attributes: { "plan" => "pro", "seats" => 3 }) }

  def assertion_for(app, amr: [ "pwd" ])
    xml = Base64.decode64(described_class.new(app).success(
      end_user: end_user, acs_url: app.default_acs_url, in_response_to: nil, session_index: "_s", authenticated_at: Time.current, amr: amr
    ))
    Nokogiri::XML(xml)
  end

  def attributes(document)
    document.xpath("//saml:Attribute", SamlIdp::Messages::NAMESPACES).to_h do |attribute|
      [ attribute["Name"], attribute.xpath("saml:AttributeValue", SamlIdp::Messages::NAMESPACES).map(&:text) ]
    end
  end

  it "sends each mapped attribute from its source, as strings" do
    mappings = %w[email email_verified name uid groups custom:plan custom:seats custom:missing].map { |source| { "name" => source, "source" => source } }
    app = create(:saml_app, project: project, attribute_mappings: mappings)

    expect(attributes(assertion_for(app))).to eq(
      "email" => [ "casey@shop.test" ], "email_verified" => [ "true" ], "name" => [ "" ], "uid" => [ end_user.uid ],
      "groups" => [ "All end users" ], "custom:plan" => [ "pro" ], "custom:seats" => [ "3" ], "custom:missing" => []
    )
  end

  it "says how the user signed in" do
    app = create(:saml_app, project: project)
    context = ->(amr) { assertion_for(app, amr: amr).at_xpath("//saml:AuthnContextClassRef", SamlIdp::Messages::NAMESPACES).text }

    expect(context.([ "pwd", "otp" ])).to eq(described_class::MFA_CONTEXT)
    expect(context.([ "pwd" ])).to eq(described_class::PASSWORD_CONTEXT)
    expect(context.([ "fed" ])).to eq(described_class::UNSPECIFIED_CONTEXT)
  end
end
