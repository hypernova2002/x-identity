require "rails_helper"

RSpec.describe NewDeviceEmailJob do
  let(:user) { create(:user, name: "Olive") }
  let(:dublin) { GeoIp::Location.new(city: "Dublin", region: "Leinster", country_code: "IE") }
  let(:new_york) { GeoIp::Location.new(city: "New York", region: "New York", country_code: "US") }
  let(:iphone) { "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" }

  def sign_in(subject, location: dublin, user_agent: CHROME_ON_MAC, ip: "81.17.240.1")
    allow(GeoIp).to receive(:default).and_return(instance_double(GeoIp, lookup: location))
    DeviceSession.start!(subject: subject, amr: [ "pwd" ], authenticated_at: Time.current, ip: ip, user_agent: user_agent)
  end

  def deliveries_for(device)
    expect { described_class.perform_now(device_session_id: device.id) }.to change(ActionMailer::Base.deliveries, :count)
    ActionMailer::Base.deliveries.last
  end

  def no_email_for(device)
    expect { described_class.perform_now(device_session_id: device.id) }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it "is queued for every new device session" do
    expect { sign_in(user) }.to have_enqueued_job(described_class)
  end

  it "doesn't email about a user's first sign-in" do
    no_email_for(sign_in(user))
  end

  it "doesn't email about a device and country used in the last 90 days" do
    sign_in(user)

    travel 89.days do
      no_email_for(sign_in(user))
    end
  end

  it "emails about a new device, a new country, or a device not used for 90 days" do
    sign_in(user)

    expect(deliveries_for(sign_in(user, user_agent: iphone)).subject).to eq("New sign-in to your #{user.account.name} account")
    expect(deliveries_for(sign_in(user, location: new_york)).to).to eq([ user.email ])
    travel 91.days do
      deliveries_for(sign_in(user))
    end
  end

  it "only emails about an unknown country when the device itself is new" do
    sign_in(user)

    no_email_for(sign_in(user, location: nil))
    deliveries_for(sign_in(user, location: nil, user_agent: iphone))
  end

  it "never emails about unrecognised devices" do
    sign_in(user)

    no_email_for(sign_in(user, user_agent: nil))
  end

  it "describes the device and links to the device list, and records that it was sent" do
    sign_in(user)

    mail = deliveries_for(sign_in(user, location: new_york, ip: "198.51.100.8"))

    expect(mail.body.to_s).to include("Chrome on Mac", "approximately New York, US", "198.51.100.8", "/console/security", "DB-IP")
    expect(AuditEvent.last).to have_attributes(action: "user.new_device_notified", target_uid: user.uid)
  end

  it "sends end users to the app portal" do
    end_user = create(:end_user)
    sign_in(end_user)

    mail = deliveries_for(sign_in(end_user, location: new_york))

    expect(mail.subject).to eq("New sign-in to your #{end_user.project.name} account")
    expect(mail.body.to_s).to include("/auth/#{end_user.project.account.slug}/#{end_user.project.uid}/apps")
  end

  it "respects the account's or project's setting" do
    sign_in(user)
    user.account.auth_configuration!.update!(notify_new_devices: false)

    no_email_for(sign_in(user, location: new_york))
  end

  it "doesn't email disabled users" do
    sign_in(user)
    device = sign_in(user, location: new_york)
    user.update!(status: "disabled")

    no_email_for(device)
  end
end
