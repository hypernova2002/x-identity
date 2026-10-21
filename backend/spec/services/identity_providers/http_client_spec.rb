require "rails_helper"

RSpec.describe IdentityProviders::HttpClient do
  subject(:client) { described_class.new }

  it "fetches JSON over https" do
    stub_request(:get, "https://idp.example.com/jwks").to_return(json_response({ keys: [] }))

    expect(client.get_json("https://idp.example.com/jwks")).to eq("keys" => [])
  end

  it "refuses plain http" do
    expect { client.get_json("http://idp.example.com/jwks") }.to raise_error(described_class::Error, /https/)
  end

  it "refuses hosts that resolve to private or loopback addresses" do
    [ "10.0.0.5", "127.0.0.1", "169.254.169.254", "::1", "::ffff:192.168.1.1" ].each do |address|
      allow(Resolv).to receive(:getaddresses).with("internal.example.com").and_return([ address ])

      expect { client.get_json("https://internal.example.com/") }.to raise_error(described_class::Error, /private/), address
    end
  end

  it "reports OAuth errors without the response body" do
    stub_request(:post, "https://idp.example.com/token").to_return(json_response({ error: "invalid_grant" }, status: 400))

    expect { client.post_form("https://idp.example.com/token", { "code" => "x" }) }.to raise_error(described_class::Error, "idp.example.com answered 400 (invalid_grant)")
  end
end
