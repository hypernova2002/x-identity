require "rails_helper"

RSpec.describe IdentityProvider do
  it "needs a secret for Google and OIDC" do
    expect(build(:identity_provider, client_secret: nil)).not_to be_valid
    expect(build(:identity_provider, :oidc, client_secret: nil)).not_to be_valid
  end

  it "needs Apple's team id, key id and a valid EC key" do
    expect(build(:identity_provider, :apple)).to be_valid
    expect(build(:identity_provider, :apple, apple_team_id: "short")).not_to be_valid
    expect(build(:identity_provider, :apple, apple_private_key: OpenSSL::PKey::RSA.generate(2048).to_pem)).not_to be_valid
  end

  it "needs loaded discovery metadata for OIDC" do
    expect(build(:identity_provider, :oidc, metadata: {})).not_to be_valid
  end

  it "needs the openid scope, except for Apple" do
    expect(build(:identity_provider, scopes: "email profile")).not_to be_valid
    expect(build(:identity_provider, :apple, scopes: "email profile")).to be_valid
  end

  it "accepts ID tokens for its client id and the additional audiences" do
    provider = build(:identity_provider, client_id: "web", additional_audiences: %w[ios android])

    expect(provider.audiences).to eq(%w[web ios android])
  end

  it "accepts either Google issuer" do
    expect(build(:identity_provider).issuers).to eq(%w[https://accounts.google.com accounts.google.com])
  end

  it "encrypts secrets" do
    provider = create(:identity_provider, :apple)
    raw = described_class.connection.select_one("SELECT apple_private_key FROM identity_providers WHERE id = #{provider.id}")

    expect(raw["apple_private_key"]).not_to include("BEGIN")
  end

  describe "SAML providers" do
    let(:provider) { build(:identity_provider, :saml) }

    it "needs web URLs for sign-on and, when given, logout" do
      provider.assign_attributes(saml_sso_url: "http://idp.acme.com/sso", saml_slo_url: "ftp://idp.acme.com/slo")

      expect(error_codes(provider, :saml_sso_url)).to eq([ :not_web_url ])
      expect(error_codes(provider, :saml_slo_url)).to eq([ :not_web_url ])
    end

    it "needs one to a few readable certificates, and skips unreadable ones when verifying" do
      provider.saml_idp_certificates = []
      expect(error_codes(provider, :saml_idp_certificates)).to eq([ :invalid_certificate_list ])

      readable = SamlCertificate.generate!(project: create(:project), status: "active").certificate
      provider.saml_idp_certificates = [ readable, "not a certificate" ]
      expect(error_codes(provider, :saml_idp_certificates)).to eq([ :invalid_certificate_list ])
      expect(provider.saml_x509_certificates.size).to eq(1)
    end
  end

  describe "domains" do
    let(:project) { create(:project) }

    it "takes a short list of domain names" do
      [ "not a list", [ "acme" ], Array.new(described_class::MAX_DOMAINS + 1) { |index| "d#{index}.com" } ].each do |domains|
        expect(error_codes(build(:identity_provider, project: project, domains: domains), :domains)).to eq([ :invalid_domain_list ]), domains.to_s
      end
    end

    it "refuses domains another of the project's providers has" do
      create(:identity_provider, :saml, project: project, domains: [ "acme.com" ])
      provider = build(:identity_provider, project: project, domains: [ "acme.com", "acme.org" ])

      expect(error_codes(provider, :domains)).to eq([ :domains_taken ])
      expect(provider.errors.details[:domains].first).to include(domains: [ "acme.com" ])
      expect(build(:identity_provider, domains: [ "acme.com" ])).to be_valid
    end
  end

  it "takes additional audiences as a short list of short strings" do
    [ "aud", [ "" ], [ 1 ], [ "a" * 256 ], Array.new(described_class::MAX_AUDIENCES + 1) { |index| "aud-#{index}" } ].each do |audiences|
      expect(error_codes(build(:identity_provider, additional_audiences: audiences), :additional_audiences)).to eq([ :invalid_audience_list ]), audiences.to_s
    end
  end

  it "has no Apple signing key without a valid EC key" do
    expect(build(:identity_provider, :apple, apple_private_key: nil).apple_signing_key).to be_nil
    expect(build(:identity_provider, :apple, apple_private_key: OpenSSL::PKey::RSA.generate(2048).to_pem).apple_signing_key).to be_nil
    expect(build(:identity_provider, :apple, apple_private_key: "garbage").apple_signing_key).to be_nil
  end
end
