require "rails_helper"

RSpec.describe Auth::ChallengePolicy do
  let(:account) { create(:account) }
  let(:relying_party) { Passkeys::RelyingParties.console(account) }
  let(:password) { %w[pwd] }

  def configuration(**settings)
    account.auth_configuration!.tap { |configuration| configuration.assign_attributes(settings) }
  end

  def next_for(user, amr = password, relying_party: self.relying_party, **settings)
    described_class.new(configuration: configuration(**settings), relying_party: relying_party).next_for(user, amr)
  end

  def with_passkey(user)
    user.webauthn_credentials.create!(external_id: SecureRandom.hex(8), public_key: "key", rp_id: relying_party.id, name: "Phone")
    user
  end

  def challenge(name, mfa_methods = [])
    Auth::Challenge.new(name: name, mfa_methods: mfa_methods)
  end

  let(:plain) { create(:user, account: account) }
  let(:with_app) { create(:user, :with_mfa, account: account) }

  describe "a second factor" do
    it "asks users with an authenticator app for a code, offering a passkey where they have one here" do
      expect(next_for(with_app)).to eq(challenge("otp", %w[otp]))
      expect(next_for(with_passkey(with_app))).to eq(challenge("otp", %w[otp passkey]))
      expect(next_for(with_app, relying_party: nil)).to eq(challenge("otp", %w[otp]))
    end

    it "asks users with only a passkey for it where MFA is required, and not where it's optional" do
      user = with_passkey(plain)

      expect(next_for(user, mfa_requirement: "required")).to eq(challenge("passkey", %w[passkey]))
      expect(next_for(user, mfa_requirement: "optional")).to be_nil
    end

    it "is satisfied by a code or an unlocked passkey, and skipped when MFA is off" do
      expect(next_for(with_app, %w[pwd otp])).to be_nil
      expect(next_for(with_passkey(with_app), %w[hwk user])).to be_nil
      expect(next_for(with_app, mfa_requirement: "off")).to be_nil
    end
  end

  describe "setting up" do
    it "asks for an authenticator app where MFA is required and none is set up" do
      expect(next_for(plain, mfa_requirement: "required")).to eq(challenge("mfa_setup"))
      expect(next_for(plain, %w[swk user], mfa_requirement: "required")).to be_nil
    end

    it "asks for a new password once it has expired, after any second factor" do
      plain.update!(password_changed_at: 2.days.ago)

      expect(next_for(plain, password_max_age_seconds: 1.day.to_i)).to eq(challenge("new_password"))
      expect(next_for(plain, %w[fed], password_max_age_seconds: 1.day.to_i)).to be_nil
    end
  end

  describe "required passkeys" do
    it "asks for the passkey, or to set one up, wherever passkeys work, before anything else" do
      expect(next_for(with_app, passkeys: "required")).to eq(challenge("passkey_setup"))
      expect(next_for(with_passkey(with_app), passkeys: "required")).to eq(challenge("passkey", %w[passkey]))
      expect(next_for(with_app, %w[pwd otp], passkeys: "required")).to eq(challenge("passkey", %w[passkey]))
      expect(next_for(with_app, %w[hwk user], passkeys: "required")).to be_nil
    end

    it "requires MFA instead where passkeys can't work" do
      expect(next_for(plain, relying_party: nil, passkeys: "required")).to eq(challenge("mfa_setup"))
      expect(next_for(with_app, relying_party: nil, passkeys: "required")).to eq(challenge("otp", %w[otp]))
    end
  end

  it "asks a user recovering a lost passkey to add a new one first" do
    user = with_passkey(plain)
    user.start_passkey_recovery!

    expect(next_for(user, passkeys: "optional", passwordless_after_passkey: true)).to eq(challenge("passkey_setup"))
    expect(next_for(user, passkeys: "optional", passwordless_after_passkey: false)).to be_nil
    expect(next_for(user, relying_party: nil, passkeys: "optional", passwordless_after_passkey: true)).to be_nil
  end
end

RSpec.describe Auth::Challenge do
  it "is answered by its own name, or by a passkey where one is offered" do
    otp = described_class.new(name: "otp", mfa_methods: %w[otp passkey])

    expect(otp.answered_by?("otp")).to be(true)
    expect(otp.answered_by?("passkey")).to be(true)
    expect(described_class.new(name: "otp", mfa_methods: %w[otp]).answered_by?("passkey")).to be(false)
    expect(described_class.new(name: "mfa_setup").answered_by?("otp")).to be(false)
  end
end
