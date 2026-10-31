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

  describe "machine-to-machine apps" do
    it "are confidential and have nothing a browser uses" do
      app = build(:app_client, machine: true, client_type: "public", allowed_origins: [ "https://shop.example.com" ],
        redirect_uris: [ "https://shop.example.com/cb" ], post_logout_redirect_uris: [ "https://shop.example.com/bye" ], launch_url: "https://shop.example.com")

      expect(error_codes(app, :client_type)).to eq([ :machine_app_not_confidential ])
      %i[allowed_origins redirect_uris post_logout_redirect_uris launch_url].each do |field|
        expect(app.errors.details[field].map { |detail| detail[:error] }).to eq([ :not_for_machine_apps ]), field.to_s
      end
    end
  end

  it "takes a short list of origins, without paths" do
    expect(error_codes(build(:app_client, allowed_origins: "https://shop.example.com"), :allowed_origins)).to eq([ :invalid_origin_list ])
    expect(error_codes(build(:app_client, allowed_origins: Array.new(described_class::MAX_ORIGINS + 1) { |i| "https://a#{i}.example.com" }), :allowed_origins))
      .to eq([ :invalid_origin_list ])
    expect(error_codes(build(:app_client, allowed_origins: [ "https://shop.example.com/path", 1 ]), :allowed_origins)).to eq([ :invalid_origins ])
  end

  it "needs a web URL for the portal launch, and lists of redirect URIs" do
    expect(error_codes(build(:app_client, launch_url: "javascript:alert(1)"), :launch_url)).to eq([ :not_web_url ])
    expect(error_codes(build(:app_client, redirect_uris: "https://shop.example.com/cb"), :redirect_uris)).to eq([ :invalid_redirect_uri_list ])
    expect(error_codes(build(:app_client, post_logout_redirect_uris: [ "https://shop.example.com/#{'a' * 2048}" ]), :post_logout_redirect_uris))
      .to eq([ :invalid_redirect_uris ])
    expect(error_codes(build(:app_client, redirect_uris: [ "https://exa mple.com/cb" ]), :redirect_uris)).to eq([ :invalid_redirect_uris ])
  end

  it "lets the portal return only to the project's own signed-out page" do
    portal = create(:project).portal_client!

    expect(portal.post_logout_redirect_uri_allowed?(ProjectEndpoints.new(portal.project).hosted_page("signed-out"))).to be(true)
    expect(portal.post_logout_redirect_uri_allowed?("https://shop.example.com/bye")).to be(false)
  end
end
