require "rails_helper"

RSpec.describe SamlSp::IdpMetadata do
  let(:certificate) { SamlCertificate.generate!(project: create(:project), status: "active").x509 }
  let(:base64) { Base64.strict_encode64(certificate.to_der) }

  def metadata(idp_children)
    %(<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" entityID="https://idp.acme.com">) +
      %(<md:IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">#{idp_children}</md:IDPSSODescriptor></md:EntityDescriptor>)
  end

  def key(value, use: "signing")
    %(<md:KeyDescriptor use="#{use}"><ds:KeyInfo><ds:X509Data><ds:X509Certificate>#{value}</ds:X509Certificate></ds:X509Data></ds:KeyInfo></md:KeyDescriptor>)
  end

  let(:sso) { %(<md:SingleSignOnService Binding="#{SamlIdp::Messages::REDIRECT_BINDING}" Location="https://idp.acme.com/sso"/>) }

  it "reads the entity ID, Redirect endpoints and signing certificates, skipping unreadable and repeated ones" do
    slo = %(<md:SingleLogoutService Binding="#{SamlIdp::Messages::REDIRECT_BINDING}" Location="https://idp.acme.com/slo"/>)

    expect(described_class.parse(metadata(key(base64) + key(base64) + key("bm9wZQ==") + key(base64, use: "encryption") + sso + slo))).to eq(
      saml_idp_entity_id: "https://idp.acme.com", saml_sso_url: "https://idp.acme.com/sso", saml_slo_url: "https://idp.acme.com/slo",
      saml_idp_certificates: [ certificate.to_pem ]
    )
    expect(described_class.parse(metadata(sso))).not_to have_key(:saml_slo_url)
  end

  it "refuses metadata without an identity provider, a Redirect sign-on URL, or valid XML" do
    post_only = %(<md:SingleSignOnService Binding="#{SamlIdp::Messages::POST_BINDING}" Location="https://idp.acme.com/sso"/>)
    no_idp = %(<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" entityID="x"/>)

    { no_idp => "no_saml_identity_provider", metadata(post_only) => "no_redirect_sso_url", "<oops" => "unreadable_saml_metadata" }.each do |xml, code|
      expect { described_class.parse(xml) }.to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "metadata", code: code) }
    end
  end
end
