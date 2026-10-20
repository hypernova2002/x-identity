require "rails_helper"

RSpec.describe OtpCredential do
  let(:credential) { described_class.generate(subject: create(:user)).tap(&:save!) }
  let(:totp) { ROTP::TOTP.new(credential.secret) }

  it "accepts the current code" do
    expect(credential.verify(totp.now)).to be(true)
  end

  it "rejects a wrong code" do
    expect(credential.verify("000000")).to be(false)
  end

  it "refuses to accept the same code twice" do
    code = totp.now
    credential.verify(code)

    expect(credential.reload.verify(code)).to be(false)
  end

  it "stores the secret encrypted" do
    raw = described_class.connection.select_value("SELECT secret FROM otp_credentials WHERE id = #{credential.id}")

    expect(raw).not_to include(credential.secret)
  end
end
