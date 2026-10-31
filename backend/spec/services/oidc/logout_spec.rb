require "rails_helper"

RSpec.describe Oidc::Logout do
  let(:project) { create(:project) }
  let(:endpoints) { ProjectEndpoints.new(project) }
  let(:after_logout) { "https://shop.example.com/signed-out" }
  let(:app_client) { create(:app_client, project: project, post_logout_redirect_uris: [ after_logout ]) }
  let(:end_user) { create(:end_user, project: project) }
  let(:logout) { described_class.new(project: project, endpoints: endpoints, ip: "203.0.113.10") }

  def id_token_for(user, client: app_client)
    tokens_for(user, app_client: client).id_token
  end

  def log_out(session_token: nil, **params)
    logout.call(session_token: session_token, params: params.transform_keys(&:to_s))
  end

  def error_page?(url)
    url.start_with?(endpoints.hosted_page("error"))
  end

  describe "the browser's session" do
    it "ends the session in the cookie, and records it" do
      session, token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)

      log_out(session_token: token)

      expect(session.reload.revoked_at).to be_present
      expect(AuditEvent.last).to have_attributes(action: "end_user.signed_out", target_uid: end_user.uid, metadata: { "sso" => true })
    end

    it "carries on without a cookie, or with one for a session that's gone or in another project" do
      other_session, other_token = BrowserSession.start!(end_user: create(:end_user), amr: [ "pwd" ], authenticated_at: Time.current)

      [ nil, "", "unknown-token", other_token ].each do |token|
        expect(log_out(session_token: token)).to eq(endpoints.hosted_page("signed-out"))
      end
      expect(other_session.reload.revoked_at).to be_nil
      expect(AuditEvent.where(action: "end_user.signed_out")).to be_empty
    end
  end

  describe "where the browser goes next" do
    it "goes to the hosted signed-out page without a post-logout address" do
      expect(log_out(client_id: app_client.uid)).to eq(endpoints.hosted_page("signed-out"))
    end

    it "returns to a registered address, with the app's state when it sent one" do
      expect(log_out(client_id: app_client.uid, post_logout_redirect_uri: after_logout, state: "s1")).to eq("#{after_logout}?state=s1")
      expect(log_out(client_id: app_client.uid, post_logout_redirect_uri: after_logout)).to eq(after_logout)
    end

    it "refuses addresses the app hasn't registered, and apps that don't exist or are disabled" do
      disabled = create(:app_client, project: project, enabled: false, post_logout_redirect_uris: [ after_logout ])

      expect(error_page?(log_out(client_id: app_client.uid, post_logout_redirect_uri: "https://evil.example.com"))).to be(true)
      expect(error_page?(log_out(client_id: "app_unknown", post_logout_redirect_uri: after_logout))).to be(true)
      expect(error_page?(log_out(client_id: disabled.uid, post_logout_redirect_uri: after_logout))).to be(true)
      expect(error_page?(log_out(post_logout_redirect_uri: after_logout))).to be(true)
    end
  end

  describe "finding the app from an ID token hint" do
    it "uses the hint's audience when there's no client_id" do
      expect(log_out(id_token_hint: id_token_for(end_user), post_logout_redirect_uri: after_logout)).to eq(after_logout)
    end

    it "accepts an expired hint, since only its signature and issuer matter" do
      hint = id_token_for(end_user)

      travel 1.year do
        expect(log_out(id_token_hint: hint, post_logout_redirect_uri: after_logout)).to eq(after_logout)
      end
    end

    it "ignores a hint it can't trust: malformed, tampered, from an unknown key or another project" do
      hint = id_token_for(end_user)
      header, payload, signature = hint.split(".")
      claims = JWT.decode(hint, nil, false).first
      tampered = [ header, Base64.urlsafe_encode64(claims.merge("aud" => "app_other").to_json, padding: false), signature ].join(".")
      unknown_key = [ Base64.urlsafe_encode64({ alg: "ES256", kid: "unknown" }.to_json, padding: false), payload, signature ].join(".")
      other_project = create(:project)
      foreign = id_token_for(create(:end_user, project: other_project), client: create(:app_client, project: other_project))

      [ "not-a-jwt", tampered, unknown_key, foreign ].each do |untrusted|
        expect(error_page?(log_out(id_token_hint: untrusted, post_logout_redirect_uri: after_logout))).to be(true)
      end
    end

    it "prefers client_id over the hint" do
      other = create(:app_client, project: project, post_logout_redirect_uris: [ "https://other.example.com/bye" ])

      expect(log_out(client_id: other.uid, id_token_hint: id_token_for(end_user), post_logout_redirect_uri: "https://other.example.com/bye"))
        .to eq("https://other.example.com/bye")
    end
  end
end
