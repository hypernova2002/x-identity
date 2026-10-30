require "rails_helper"

RSpec.describe PruneExpiredRecordsJob do
  let(:end_user) { create(:end_user) }

  it "deletes used and expired one-time tokens of every user, keeping usable ones" do
    used, = OneTimeToken.issue!(subject: end_user, purpose: :password_reset).tap { |record, _| record.consume! }
    expired, = OneTimeToken.issue!(subject: create(:end_user), purpose: :email_verification).tap { |record, _| record.update!(expires_at: 1.minute.ago) }
    usable, = OneTimeToken.issue!(subject: create(:end_user), purpose: :email_verification)

    described_class.perform_now

    expect([ used, expired, usable ].map { |record| OneTimeToken.exists?(record.id) }).to eq([ false, false, true ])
  end

  it "deletes refresh tokens of ended sessions, keeping used tokens of live ones for reuse detection" do
    issuer = Auth::TokenIssuer.new(realm: end_user.realm, app_client: create(:app_client, project: end_user.project))
    token = ->(family) { RefreshToken.find_by_token(issuer.issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ], family_id: family).refresh_token) }
    used = token.call("live").tap(&:mark_used!)
    revoked = token.call("ended")
    RefreshToken.revoke_family!("ended")

    described_class.perform_now

    expect([ RefreshToken.exists?(used.id), RefreshToken.exists?(revoked.id) ]).to eq([ true, false ])
  end

  it "deletes hosted login sessions that ended over a day ago, with their app sessions" do
    ended, = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
    ended.browser_session_apps.create!(saml_app: create(:saml_app, project: end_user.project), session_index: "idx", name_id: end_user.email)
    ended.revoke!

    travel(2.days) do
      recent, = BrowserSession.start!(end_user: create(:end_user, project: end_user.project), amr: [ "pwd" ], authenticated_at: Time.current)
      recent.revoke!
      described_class.perform_now

      expect([ BrowserSession.exists?(ended.id), BrowserSessionApp.exists?(browser_session_id: ended.id), BrowserSession.exists?(recent.id) ])
        .to eq([ false, false, true ])
    end
  end

  it "deletes expired SAML assertion IDs, keeping ones that could still be replayed" do
    provider = create(:identity_provider, project: end_user.project)
    ConsumedSamlAssertion.consume(provider, "old", 1.minute.ago)
    ConsumedSamlAssertion.consume(provider, "current", 5.minutes.from_now)

    described_class.perform_now

    expect(ConsumedSamlAssertion.pluck(:assertion_id)).to eq(%w[current])
  end
end
