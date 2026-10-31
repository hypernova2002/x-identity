require "rails_helper"

RSpec.describe IdentityProviders::IdTokenVerifier do
  let(:provider) { create(:identity_provider, :oidc) }
  let(:verifier) { described_class.new(provider: provider) }

  it "verifies the token against the provider's keys and the nonce" do
    stub_provider_jwks(provider)

    expect(verifier.verify(provider_id_token(provider, nonce: "nonce-1"), nonce: "nonce-1")).to include("sub" => "provider-user-1")
  end

  it "refuses a token when no nonce was expected, or it has none" do
    stub_provider_jwks(provider)

    expect { verifier.verify(provider_id_token(provider, nonce: "nonce-1"), nonce: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_id_token) }
    expect { verifier.verify(provider_id_token(provider, nonce: nil), nonce: "nonce-1") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_id_token) }
  end

  it "reports a provider whose keys can't be fetched" do
    stub_request(:get, provider.endpoints["jwks_uri"]).to_return(status: 503, body: "{}")

    expect { verifier.verify(provider_id_token(provider), nonce: "nonce-for-specs-123456") }
      .to raise_error(ApiError) { |error| expect(error.code).to eq(:identity_provider_error) }
  end
end
