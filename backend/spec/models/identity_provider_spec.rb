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
end
