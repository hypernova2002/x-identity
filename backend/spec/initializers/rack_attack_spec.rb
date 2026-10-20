require "rails_helper"

RSpec.describe "Rack::Attack throttled responder" do
  let(:request) do
    env = Rack::MockRequest.env_for("/v1/anything")
    env["rack.attack.match_data"] = { period: 300, epoch_time: 1_000 }
    Rack::Attack::Request.new(env)
  end

  let(:status_headers_body) { Rack::Attack.throttled_responder.call(request) }

  it "responds with 429" do
    expect(status_headers_body[0]).to eq(429)
  end

  it "tells the client when to retry" do
    expect(status_headers_body[1]["retry-after"]).to eq("200")
  end

  it "renders the rate_limited error" do
    expect(JSON.parse(status_headers_body[2].first).dig("error", "code")).to eq("rate_limited")
  end
end
