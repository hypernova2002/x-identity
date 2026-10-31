require "rails_helper"

RSpec.describe IdentityProviders::KeySet do
  let(:http_client) { instance_double(IdentityProviders::HttpClient) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:key_set) { described_class.new(http_client: http_client, cache: cache) }
  let(:jwks_uri) { "https://idp.example.com/jwks" }
  let(:old_key) { JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: "old") }
  let(:new_key) { JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: "new") }

  def kids(options = {})
    key_set.loader(jwks_uri).call(options).map { |jwk| jwk[:kid] }
  end

  before do
    allow(http_client).to receive(:get_json).with(jwks_uri).and_return(JWT::JWK::Set.new(old_key).export, JWT::JWK::Set.new(new_key).export)
  end

  it "keeps the provider's keys for an hour" do
    expect(kids).to eq([ "old" ])
    expect(kids).to eq([ "old" ])

    travel(described_class::TTL + 1.second) { expect(kids).to eq([ "new" ]) }
    expect(http_client).to have_received(:get_json).twice
  end

  it "refetches once for a key it doesn't know, then not again for a minute" do
    kids

    expect(kids(kid_not_found: true)).to eq([ "new" ])
    expect(kids(kid_not_found: true)).to eq([ "new" ])
    expect(http_client).to have_received(:get_json).twice

    travel(described_class::REFETCH_INTERVAL + 1.second) do
      allow(http_client).to receive(:get_json).with(jwks_uri).and_return(JWT::JWK::Set.new([ old_key, new_key ]).export)
      expect(kids(kid_not_found: true)).to eq([ "old", "new" ])
    end
  end
end
