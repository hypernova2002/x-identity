require "rails_helper"

RSpec.describe OneTimeToken do
  let(:end_user) { create(:end_user) }
  let(:issued) { described_class.issue_with_code!(subject: end_user, purpose: :email_verification) }

  it "issues a 6-digit code" do
    expect(issued.code).to match(/\A\d{6}\z/)
  end

  it "does not store the code in plain text" do
    expect(issued.record.code_digest).not_to include(issued.code)
  end

  it "matches the right code" do
    expect(issued.record.code_matches?(issued.code, max_attempts: 5)).to be(true)
  end

  it "stops matching after too many wrong guesses" do
    3.times { issued.record.reload.code_matches?("000000", max_attempts: 3) }

    expect(issued.record.reload.code_matches?(issued.code, max_attempts: 3)).to be(false)
  end

  it "generates another code when one is rejected" do
    allow(SecureRandom).to receive(:random_number).and_call_original
    allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(111_111, 222_222)

    issued = described_class.issue_with_code!(subject: end_user, purpose: :password_reset, reject_code: ->(code) { code == "111111" })

    expect(issued.code).to eq("222222")
  end

  it "invalidates the previous code when a new one is issued" do
    first = issued
    described_class.issue_with_code!(subject: end_user, purpose: :email_verification)

    expect(described_class.current_for(end_user, purpose: :email_verification)).not_to eq(first.record)
  end
end
