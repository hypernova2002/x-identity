require "rails_helper"

RSpec.describe SamlIdp::Messages do
  let(:keys) { SamlCertificate.generate!(project: create(:project), status: "active") }
  let(:xml) { %(<samlp:LogoutRequest xmlns:samlp="#{described_class::PROTOCOL}" ID="_1"/>) }

  it "refuses messages that aren't deflated, too large, or declare a document type" do
    expect { described_class.decode(Base64.strict_encode64(xml), deflated: true) }.to raise_error(described_class::Error, "The SAML message isn't deflated correctly.")
    expect { described_class.parse("<a>#{'x' * described_class::MAX_BYTES}</a>") }.to raise_error(described_class::Error, "The SAML message is too large.")
    expect { described_class.parse(%(<!DOCTYPE a [<!ENTITY x "y">]><a>&x;</a>)) }.to raise_error(described_class::Error, /document type/)
  end

  it "adds the signed query to a URL that already has one" do
    url = described_class.redirect_url("https://sp.example.com/slo?tenant=1", type: "SAMLRequest", xml: xml, relay_state: nil, certificate: keys)

    expect(url).to start_with("https://sp.example.com/slo?tenant=1&SAMLRequest=")
    expect(described_class.redirect_signature_valid?(URI.parse(url).query.delete_prefix("tenant=1&"), type: "SAMLRequest", certificate: keys.x509)).to be(true)
  end

  it "treats signatures it can't check as invalid" do
    query = URI.parse(described_class.redirect_url("https://sp.example.com/slo", type: "SAMLRequest", xml: xml, relay_state: nil, certificate: keys)).query

    expect(described_class.redirect_signature_valid?(query.sub(/Signature=[^&]+/, "Signature=%%%"), type: "SAMLRequest", certificate: keys.x509)).to be(false)
    expect(described_class.redirect_signature_valid?("SAMLRequest=x", type: "SAMLRequest", certificate: keys.x509)).to be(false)
    expect(described_class.embedded_signature_valid?(xml, keys.x509)).to be(false)
    expect(described_class.embedded_signature_valid?(described_class.sign(xml, keys).sub("_1", "_2"), keys.x509)).to be(false)
  end

  it "treats a signature library error as an invalid signature" do
    query = URI.parse(described_class.redirect_url("https://sp.example.com/slo", type: "SAMLRequest", xml: xml, relay_state: nil, certificate: keys)).query
    allow(OneLogin::RubySaml::Utils).to receive(:verify_signature).and_raise(OpenSSL::PKey::PKeyError)
    allow_any_instance_of(XMLSecurity::SignedDocument).to receive(:validate_document_with_cert).and_raise(ArgumentError)

    expect(described_class.redirect_signature_valid?(query, type: "SAMLRequest", certificate: keys.x509)).to be(false)
    expect(described_class.embedded_signature_valid?(described_class.sign(xml, keys), keys.x509)).to be(false)
  end
end
