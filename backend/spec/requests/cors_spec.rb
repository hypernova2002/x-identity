require "rails_helper"

RSpec.describe "CORS", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CORS_ALLOWED_ORIGINS", "").and_return("https://console.example.com")
  end

  def preflight(origin)
    process :options, "/up", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "GET"
    }
  end

  it "allows preflight requests from a configured origin" do
    preflight("https://console.example.com")

    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://console.example.com")
  end

  it "does not allow preflight requests from other origins" do
    preflight("https://evil.example.com")

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end
