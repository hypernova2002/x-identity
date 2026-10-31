require "rails_helper"

RSpec.describe IdentityProviders::Discovery do
  let(:http_client) { instance_double(IdentityProviders::HttpClient) }
  let(:discovery) { described_class.new(http_client: http_client) }
  let(:document) do
    {
      "issuer" => "https://idp.example.com", "authorization_endpoint" => "https://idp.example.com/authorize",
      "token_endpoint" => "https://idp.example.com/token", "jwks_uri" => "https://idp.example.com/jwks",
      "code_challenge_methods_supported" => [ "S256" ], "userinfo_endpoint" => "https://idp.example.com/userinfo"
    }
  end
  let(:well_known) { "https://idp.example.com/.well-known/openid-configuration" }

  def detail(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.details.first }
  end

  it "loads the document from the issuer or its full URL, keeping only what sign-in needs" do
    allow(http_client).to receive(:get_json).with(well_known).and_return(document)

    expect(discovery.fetch("https://idp.example.com/")).to eq(document.except("userinfo_endpoint"))
    expect(discovery.fetch(well_known)).to eq(document.except("userinfo_endpoint"))
  end

  it "refuses documents missing an endpoint, or with one that isn't https" do
    allow(http_client).to receive(:get_json).and_return(document.except("jwks_uri").merge("token_endpoint" => "http://idp.example.com/token"))

    expect(detail { discovery.fetch(well_known) }).to include(field: "discovery_url", code: "incomplete_discovery", params: { missing: %w[token_endpoint jwks_uri] })
  end

  it "refuses a document for another issuer" do
    allow(http_client).to receive(:get_json).and_return(document.merge("issuer" => "https://evil.example.com"))

    expect(detail { discovery.fetch(well_known) }).to include(field: "discovery_url", code: "discovery_issuer_mismatch")
  end

  it "says why the document couldn't be loaded" do
    allow(http_client).to receive(:get_json).and_raise(IdentityProviders::HttpClient::Error, "idp.example.com answered 404")

    expect(detail { discovery.fetch(well_known) }).to include(field: "discovery_url", code: "not_loadable", params: { reason: "idp.example.com answered 404" })
  end
end
