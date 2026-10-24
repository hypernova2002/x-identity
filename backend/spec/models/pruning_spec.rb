require "rails_helper"

RSpec.describe "Cleaning up as new rows are created" do
  let(:end_user) { create(:end_user) }

  def start_device(subject)
    DeviceSession.start!(subject: subject, amr: [ "pwd" ], authenticated_at: Time.current, ip: nil, user_agent: CHROME_ON_MAC)
  end

  it "deletes signing keys that are no longer published when a new key is generated" do
    account = create(:account)
    configuration = account.auth_configuration!
    first = SigningKeys::Rotator.new(owner: account, configuration: configuration).current

    travel(configuration.signing_key_rotation + 1.day) { SigningKeys::Rotator.new(owner: account, configuration: configuration).current }
    expect(SigningKey.exists?(first.id)).to be(true)

    travel((configuration.signing_key_rotation * 2) + 2.days) { SigningKeys::Rotator.new(owner: account, configuration: configuration).current }
    expect(SigningKey.exists?(first.id)).to be(false)
  end

  it "deletes a subject's used and expired one-time tokens when issuing another" do
    old, = OneTimeToken.issue!(subject: end_user, purpose: :password_reset)
    other_purpose, = OneTimeToken.issue!(subject: end_user, purpose: :email_verification)

    current, = OneTimeToken.issue!(subject: end_user, purpose: :password_reset)

    expect([ OneTimeToken.exists?(old.id), OneTimeToken.exists?(current.id), OneTimeToken.exists?(other_purpose.id) ]).to eq([ false, true, true ])
  end

  it "deletes refresh tokens of ended sessions, but keeps used tokens of live ones for reuse detection, at the next sign-in" do
    live = Auth::TokenIssuer.new(realm: end_user.realm, app_client: create(:app_client, project: end_user.project))
    first = live.issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ], family_id: "live")
    used = RefreshToken.find_by_token(first.refresh_token).tap(&:mark_used!)
    live.issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ], family_id: "live")
    revoked = RefreshToken.find_by_token(live.issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ], family_id: "ended").refresh_token)
    RefreshToken.revoke_family!("ended")

    start_device(end_user)

    expect([ RefreshToken.exists?(used.id), RefreshToken.exists?(revoked.id), RefreshToken.where(family_id: "live").count ]).to eq([ true, false, 2 ])
  end

  it "deletes hosted login sessions that ended over a day ago, with their app sessions" do
    ended, = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
    ended.browser_session_apps.create!(saml_app: create(:saml_app, project: end_user.project), session_index: "idx", name_id: end_user.email)
    ended.revoke!

    travel(2.days) { start_device(end_user) }

    expect([ BrowserSession.exists?(ended.id), BrowserSessionApp.where(browser_session_id: ended.id).exists? ]).to eq([ false, false ])
  end

  it "deletes device sessions that ended and were last seen over 90 days ago, keeping the latest" do
    stale = start_device(end_user).tap(&:revoke!)
    latest_old = start_device(end_user).tap(&:revoke!)

    travel(91.days) do
      start_device(end_user)
      expect([ DeviceSession.exists?(stale.id), DeviceSession.exists?(latest_old.id) ]).to eq([ false, true ])
    end
  end

  it "keeps enough history that a user back after 90 days still gets a new-device email" do
    allow(GeoIp).to receive(:default).and_return(instance_double(GeoIp, lookup: GeoIp::Location.new(city: "Dublin", region: "Leinster", country_code: "IE")))
    start_device(end_user).tap(&:revoke!)

    travel(91.days) do
      returning = start_device(end_user)
      expect(returning).to be_unfamiliar
    end
  end
end
