require "rails_helper"

RSpec.describe OtpCredential do
  let(:user) { create(:user) }

  def verify(credential, code, drift_steps: 1, look_ahead: 10)
    credential.reload.verify(code, drift_steps: drift_steps, look_ahead: look_ahead)
  end

  describe "time-based (TOTP)" do
    let(:credential) { described_class.generate(subject: user).tap(&:save!) }
    let(:totp) { ROTP::TOTP.new(credential.secret) }

    it "accepts the current code" do
      expect(verify(credential, totp.now)).to be(true)
    end

    it "rejects a wrong code" do
      expect(verify(credential, "000000")).to be(false)
    end

    it "refuses to accept the same code twice" do
      code = totp.now
      verify(credential, code)

      expect(verify(credential, code)).to be(false)
    end

    it "accepts the previous step's code within the drift" do
      expect(verify(credential, totp.at(30.seconds.ago))).to be(true)
    end

    it "rejects the previous step's code without drift" do
      expect(verify(credential, totp.at(30.seconds.ago), drift_steps: 0)).to be(false)
    end

    it "uses the digits and step length it was enrolled with" do
      credential = described_class.generate(subject: user, digits: 8, step_seconds: 60).tap(&:save!)

      expect(verify(credential, ROTP::TOTP.new(credential.secret, digits: 8, interval: 60).now)).to be(true)
    end

    it "stores the secret encrypted" do
      raw = described_class.connection.select_value("SELECT secret FROM otp_credentials WHERE id = #{credential.id}")

      expect(raw).not_to include(credential.secret)
    end
  end

  describe "counter-based (HOTP)" do
    let(:credential) { described_class.generate(subject: user, otp_type: "hotp").tap(&:save!) }
    let(:hotp) { ROTP::HOTP.new(credential.secret) }

    it "accepts the code for the current counter" do
      expect(verify(credential, hotp.at(0))).to be(true)
    end

    it "moves the counter past an accepted code" do
      verify(credential, hotp.at(0))

      expect(credential.reload.counter).to eq(1)
    end

    it "refuses to accept the same code twice" do
      verify(credential, hotp.at(0))

      expect(verify(credential, hotp.at(0))).to be(false)
    end

    it "resynchronises with codes ahead, within the look-ahead" do
      expect([ verify(credential, hotp.at(5)), credential.reload.counter ]).to eq([ true, 6 ])
    end

    it "rejects codes beyond the look-ahead" do
      expect(verify(credential, hotp.at(15), look_ahead: 10)).to be(false)
    end

    it "includes the counter in the provisioning URI" do
      expect(credential.provisioning_uri(account_name: "Acme", label: user.email)).to start_with("otpauth://hotp/").and include("counter=0")
    end
  end
end
