require "rails_helper"

RSpec.describe SamlIdp::SpMetadata do
  let(:certificate) { SamlCertificate.generate!(project: create(:project), status: "active").x509 }

  def metadata(sp_descriptor)
    %(<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" entityID="https://sp.example.com">) +
      "#{sp_descriptor}</md:EntityDescriptor>"
  end

  def key_descriptor(base64, use: "signing")
    %(<md:KeyDescriptor use="#{use}"><ds:KeyInfo><ds:X509Data><ds:X509Certificate>#{base64}</ds:X509Certificate></ds:X509Data></ds:KeyInfo></md:KeyDescriptor>)
  end

  def sp(*children)
    %(<md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">#{children.join}</md:SPSSODescriptor>)
  end

  it "reads the default POST ACS URL first, the Redirect logout URL, the signing certificate and the NameID format" do
    parsed = described_class.parse(metadata(sp(
      key_descriptor(Base64.strict_encode64(certificate.to_der).scan(/.{1,64}/).join("\n")),
      %(<md:SingleLogoutService Binding="#{SamlIdp::Messages::REDIRECT_BINDING}" Location="https://sp.example.com/slo"/>),
      "<md:NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</md:NameIDFormat>",
      %(<md:AssertionConsumerService Binding="#{SamlIdp::Messages::POST_BINDING}" Location="https://sp.example.com/acs2" index="2"/>),
      %(<md:AssertionConsumerService Binding="#{SamlIdp::Messages::POST_BINDING}" Location="https://sp.example.com/acs1" index="1" isDefault="true"/>),
      %(<md:AssertionConsumerService Binding="#{SamlIdp::Messages::REDIRECT_BINDING}" Location="https://sp.example.com/acs-redirect" index="0"/>)
    )))

    expect(parsed).to eq(
      entity_id: "https://sp.example.com", acs_urls: [ "https://sp.example.com/acs1", "https://sp.example.com/acs2" ],
      slo_url: "https://sp.example.com/slo", sp_certificate: certificate.to_pem, name_id_format: "persistent"
    )
  end

  it "leaves out what it can't find or read" do
    parsed = described_class.parse(metadata(sp(key_descriptor("bm90IGEgY2VydGlmaWNhdGU="), key_descriptor(Base64.strict_encode64(certificate.to_der), use: "encryption"))))

    expect(parsed).to eq(entity_id: "https://sp.example.com", acs_urls: [])
    expect(described_class.parse(metadata(sp(key_descriptor(" "))))).not_to have_key(:sp_certificate)
  end

  it "refuses metadata without a service provider, or that isn't XML" do
    expect { described_class.parse(metadata("")) }
      .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "metadata", code: "no_saml_service_provider") }
    expect { described_class.parse("<oops") }
      .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "metadata", code: "unreadable_saml_metadata") }
  end
end
