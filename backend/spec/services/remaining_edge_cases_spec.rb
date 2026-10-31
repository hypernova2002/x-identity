require "rails_helper"

RSpec.describe "Remaining edge cases" do
  describe GeoIp do
    it "warns and goes without locations when the database can't be read" do
      path = Rails.root.join("tmp/geoip-invalid.mmdb")
      File.write(path, "not a database")
      allow(Rails.logger).to receive(:warn)

      expect(described_class.reader_for(path)).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/couldn't be read/)
    ensure
      FileUtils.rm_f(path)
    end

    it "has no location for an address the database knows nothing useful about" do
      reader = instance_double(MaxMind::DB, get: { "continent" => { "code" => "EU" } })

      expect(described_class.new(reader).lookup("81.17.240.1")).to be_nil
    end
  end

  describe Passwords::Hasher do
    it "doesn't match a digest it can't read" do
      expect(described_class.new.matches?("password", "not-an-argon2-digest")).to be(false)
    end
  end

  describe Mfa::OtpEnrollment do
    let(:user) { create(:user, :with_mfa) }

    it "refuses turning off MFA that isn't on, or with the wrong password" do
      expect { described_class.new(user: create(:user)).disable(current_password: "x", code: "1") }
        .to raise_error(ApiError) { |error| expect(error.code).to eq(:not_found) }
      expect { described_class.new(user: user).disable(current_password: "wrong", code: current_totp_for(user)) }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "current_password", code: "incorrect") }
    end

    it "refuses confirming a setup that wasn't started" do
      expect { described_class.new(user: create(:user)).confirm(code: "123456") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_otp) }
    end
  end

  describe Auth::AccessTokenVerifier do
    it "refuses a machine app's own token on endpoints for users, even with a user app's audience" do
      project = create(:project)
      app_client = create(:app_client, project: project)
      key = SigningKeys::Rotator.new(owner: project, configuration: project.auth_configuration!).current
      now = Time.current.to_i
      claims = {
        iss: project.token_issuer, sub: "app_machine", aud: app_client.uid, exp: now + 300, iat: now, auth_time: now, sid: "s",
        token_use: "access", gty: "client_credentials"
      }
      token = JWT.encode(claims, key.signing_key, key.algorithm, { kid: key.kid })

      expect { described_class.new(realm: project.realm).verify(token) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_token) }
    end
  end

  describe Auth::ChallengeResponse do
    it "refuses an OTP answer while the user is locked out" do
      project = create(:project)
      app_client = create(:app_client, project: project)
      user = create(:end_user, :with_mfa, project: project, email: "mfa@shop.test")
      context = Auth::SignInContext.new(realm: project.realm, app_client: app_client)
      result = Auth::SignIn.new(context: context).call(email: "mfa@shop.test", password: "correct horse battery staple")
      allow(Auth::Lockout).to receive(:new).and_return(instance_double(Auth::Lockout, locked?: true))

      expect { described_class.new(context: context).call(session: result.session, challenge: "otp", code: current_totp_for(user)) }
        .to raise_error(ApiError) { |error| expect(error.code).to eq(:too_many_attempts) }
    end
  end

  describe EndUsers::AttributeValidator do
    it "refuses a date that isn't written as one" do
      project = create(:project)
      project.end_user_attribute_definitions.create!(key: "birthday", label: "Birthday", data_type: "date")

      result = described_class.new(project: project).validate({ "birthday" => 20_260_131 }, by_admin: true)

      expect(result.details.first).to include(field: "custom_attributes.birthday", code: "not_a_date")
    end
  end

  describe "serializers" do
    it "leaves out a device's location when it's unknown, and an invitation's inviter when they're gone" do
      device = DeviceSession.new(uid: "dev_1", amr: [], created_at: Time.current, last_seen_at: Time.current)
      invitation = Invitation.new(uid: "inv_1", email: "new@acme.test", role: "member", expires_at: 1.day.from_now, created_at: Time.current)

      expect(DeviceSessionSerializer.new(device).serializable_hash).to include("location" => nil)
      expect(InvitationSerializer.new(invitation).serializable_hash).to include("invited_by_uid" => nil)
    end
  end

  it "sends an invitation from an inviter who has since been deleted in the account's default language" do
    invitation, token = Invitation.issue!(account: create(:account), email: "new@acme.test", role: "member")

    expect(InvitationMailer.invitation(invitation, token).subject).to include("invited")
  end

  it "doesn't treat someone outside the project as a developer" do
    project = create(:project)

    expect(ProjectPolicy.new(create(:user, account: project.account), project).manage_app_clients?).to be(false)
  end
end
