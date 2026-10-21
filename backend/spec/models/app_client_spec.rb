require "rails_helper"

RSpec.describe AppClient do
  describe "redirect URIs" do
    let(:app_client) { build(:app_client) }

    it "accepts https, loopback http and native app schemes" do
      app_client.redirect_uris = %w[https://shop.example.com/callback http://localhost:5173/callback http://127.0.0.1:8080/cb com.example.shop:/oauth]

      expect(app_client).to be_valid
    end

    it "rejects plain http, fragments and script schemes" do
      [ "http://shop.example.com/callback", "https://shop.example.com/callback#done", "javascript:alert(1)", "/relative" ].each do |uri|
        app_client.redirect_uris = [ uri ]
        expect(app_client).not_to be_valid, uri
      end
    end

    it "matches redirect URIs exactly" do
      app_client.redirect_uris = [ "https://shop.example.com/callback" ]

      expect(app_client.redirect_uri_allowed?("https://shop.example.com/callback")).to be(true)
      expect(app_client.redirect_uri_allowed?("https://shop.example.com/callback/")).to be(false)
    end
  end
end
