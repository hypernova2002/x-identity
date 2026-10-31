require "rails_helper"

RSpec.describe "Last edge cases" do
  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }

  def raised(&block)
    expect(&block).to raise_error(ApiError) { |error| return error }
  end

  it "says a domain is already being set up when a concurrent request added it first" do
    allow_any_instance_of(ProjectDomain).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    expect(raised { Domains::Management.new(actor: admin, project: project).add(hostname: "login.acme.com") })
      .to have_attributes(code: :conflict, reason: :domain_already_being_set_up)
  end

  it "keeps one next SAML certificate at a time" do
    certificates = SamlApps::Certificates.new(actor: admin, project: project)
    certificates.add_next

    expect(raised { certificates.add_next }).to have_attributes(code: :conflict, reason: :certificate_already_waiting)
  end

  it "refuses renaming a passkey to a name that's only spaces" do
    user = create(:user)
    passkey = WebauthnCredential.create!(subject: user, external_id: "cred-1", public_key: "key", rp_id: "localhost", name: "Laptop")

    expect(raised { Passkeys::Management.new(user: user).rename(passkey, name: "   ") }.code).to eq(:validation_failed)
  end

  it "uses the signing key another request rotated in while it waited for the lock" do
    configuration = project.auth_configuration!
    rotator = SigningKeys::Rotator.new(owner: project, configuration: configuration)
    fresh = rotator.current
    stale = fresh.dup.tap { |key| key.activated_at = 10.years.ago }
    allow(rotator).to receive(:latest_signing_key).and_return(stale, fresh)

    expect(rotator.current).to eq(fresh)
    expect(project.signing_keys.count).to eq(1)
  end

  it "doesn't record a confidential client's server as the user's device" do
    expect(DeviceDetails.for(create(:app_client, :confidential), ip: "203.0.113.10", user_agent: "server")).to eq(ip: nil, user_agent: nil)
  end

  it "refuses unknown refresh tokens, email change links and passkeys" do
    user = create(:user)
    relying_party = Passkeys::RelyingParties.console(user.account)
    authentication = Passkeys::Authentication.new(realm: user.account.realm, relying_party: relying_party)
    options = authentication.options

    expect(raised { Auth::Refresh.new(realm: user.realm).call(refresh_token: "unknown") }.code).to eq(:invalid_token)
    expect(raised { Users::EmailChange.new(account: user.account).confirm(token: "unknown") }.code).to eq(:invalid_token)
    expect(raised { authentication.verify(authentication_id: options[:authentication_id], credential: { "id" => "unknown" }) }.code).to eq(:invalid_passkey)
  end

  it "shows a device's city when its country is unknown" do
    device = DeviceSession.new(uid: "dev_1", amr: [], city: "Dublin", created_at: Time.current, last_seen_at: Time.current)

    expect(DeviceSessionSerializer.new(device).serializable_hash["location"]).to eq(city: "Dublin", region: nil, country_code: nil)
  end
end
