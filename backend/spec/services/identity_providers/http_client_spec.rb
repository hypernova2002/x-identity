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

  it "sends client credentials as Basic auth when asked" do
    stub_request(:post, "https://idp.example.com/token").with(basic_auth: %w[client-1 secret-1], body: { "code" => "x" }).to_return(json_response({ access_token: "a" }))

    expect(client.post_form("https://idp.example.com/token", { "code" => "x" }, basic_auth: %w[client-1 secret-1])).to eq("access_token" => "a")
  end

  it "fetches text, such as SAML metadata, and reports a failed answer" do
    stub_request(:get, "https://idp.example.com/metadata").to_return({ body: "<EntityDescriptor/>" }, { status: 404, body: "missing" })

    expect(client.get_text("https://idp.example.com/metadata")).to eq("<EntityDescriptor/>")
    expect { client.get_text("https://idp.example.com/metadata") }.to raise_error(described_class::Error, "idp.example.com answered 404")
  end

  it "refuses URLs it can't parse, and hosts that don't resolve or resolve to 0.0.0.0" do
    expect { client.get_json("https://exa mple.com/") }.to raise_error(described_class::Error, "https://exa mple.com/ isn't a valid URL")
    expect { client.get_json("https:///jwks") }.to raise_error(described_class::Error, /must be an https URL/)

    allow(Resolv).to receive(:getaddresses).with("nowhere.example.com").and_return([])
    expect { client.get_json("https://nowhere.example.com/") }.to raise_error(described_class::Error, "nowhere.example.com doesn't resolve")

    allow(Resolv).to receive(:getaddresses).with("zero.example.com").and_return([ "0.0.0.0" ])
    expect { client.get_json("https://zero.example.com/") }.to raise_error(described_class::Error, /private/)
  end

  it "refuses responses over 1 MB" do
    stub_request(:get, "https://idp.example.com/jwks").to_return(body: "x" * (described_class::MAX_BODY_BYTES + 1))

    expect { client.get_json("https://idp.example.com/jwks") }.to raise_error(described_class::Error, "idp.example.com sent a response that is too large")
  end

  it "refuses answers that aren't a JSON object" do
    stub_request(:get, "https://idp.example.com/jwks").to_return({ body: "<html>" }, json_response([ 1, 2 ]), json_response("oops", status: 500))

    expect { client.get_json("https://idp.example.com/jwks") }.to raise_error(described_class::Error, "idp.example.com didn't return JSON")
    expect { client.get_json("https://idp.example.com/jwks") }.to raise_error(described_class::Error, "idp.example.com answered 200")
    expect { client.get_json("https://idp.example.com/jwks") }.to raise_error(described_class::Error, "idp.example.com answered 500")
  end

  it "says when the provider can't be reached, without the details" do
    [ Errno::ECONNREFUSED, Net::OpenTimeout, OpenSSL::SSL::SSLError ].each do |failure|
      stub_request(:get, "https://idp.example.com/jwks").to_raise(failure)

      expect { client.get_json("https://idp.example.com/jwks") }.to raise_error(described_class::Error, /\Acouldn't reach idp.example.com \(\w+\)\z/)
    end
  end
end
