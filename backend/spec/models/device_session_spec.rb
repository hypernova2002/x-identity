require "rails_helper"

RSpec.describe DeviceSession do
  let(:user) { create(:user) }

  describe ".start!" do
    it "describes the device and where it signed in from" do
      allow(GeoIp).to receive(:default).and_return(instance_double(GeoIp, lookup: GeoIp::Location.new(city: "Dublin", region: "Leinster", country_code: "IE")))

      device = described_class.start!(subject: user, amr: [ "pwd" ], authenticated_at: Time.current, ip: "81.17.240.1", user_agent: CHROME_ON_MAC)

      expect(device).to have_attributes(
        device_name: "Chrome on Mac", device_type: "desktop", created_ip: "81.17.240.1", last_ip: "81.17.240.1",
        city: "Dublin", region: "Leinster", country_code: "IE", project: nil
      )
      expect(device.uid).to start_with("ses_")
    end

    it "belongs to the end user's project" do
      end_user = create(:end_user)

      expect(described_class.start!(subject: end_user, amr: [], authenticated_at: Time.current, ip: nil, user_agent: nil).project).to eq(end_user.project)
    end
  end

  describe ".current" do
    it "lists devices with a working refresh token or browser session, and not signed-out ones" do
      with_token, = signed_in_device(user)
      signed_out, = signed_in_device(user)
      signed_out.revoke!
      expired, = signed_in_device(user)
      expired.refresh_tokens.update_all(expires_at: 1.minute.ago)
      end_user = create(:end_user)
      browser, _token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)

      expect(described_class.current).to contain_exactly(with_token, browser.device_session)
    end
  end

  describe "#revoke!" do
    it "revokes the device's refresh tokens and browser session" do
      end_user = create(:end_user)
      browser, _token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
      device = browser.device_session
      Auth::TokenIssuer.new(realm: end_user.realm, app_client: create(:app_client, project: end_user.project))
        .issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ], device_session: device)

      device.revoke!

      expect([ device.reload.revoked?, browser.reload.revoked_at.present?, device.refresh_tokens.all?(&:revoked?) ]).to eq([ true, true, true ])
    end
  end

  describe "#touch_activity!" do
    it "records activity at most once a minute from the same address" do
      device, = signed_in_device(user, ip: "203.0.113.10")

      travel 30.seconds do
        expect { device.touch_activity!(ip: "203.0.113.10", user_agent: CHROME_ON_MAC) }.not_to(change { device.reload.last_seen_at })
      end
      travel 2.minutes do
        expect { device.touch_activity!(ip: "203.0.113.10", user_agent: CHROME_ON_MAC) }.to(change { device.reload.last_seen_at })
      end
    end

    it "updates the address and location when the device moves" do
      device, = signed_in_device(user, ip: "203.0.113.10")
      allow(GeoIp).to receive(:default).and_return(instance_double(GeoIp, lookup: GeoIp::Location.new(city: "Cork", region: "Munster", country_code: "IE")))

      device.touch_activity!(ip: "198.51.100.20", user_agent: CHROME_ON_MAC)

      expect(device.reload).to have_attributes(last_ip: "198.51.100.20", created_ip: "203.0.113.10", city: "Cork")
    end
  end

  describe ".for_sid" do
    it "finds the device from its uid, or from a refresh token family for older tokens" do
      device, = signed_in_device(user)

      expect(described_class.for_sid(device.uid)).to eq(device)
      expect(described_class.for_sid(device.refresh_tokens.first.family_id)).to eq(device)
      expect(described_class.for_sid(nil)).to be_nil
    end
  end
end
