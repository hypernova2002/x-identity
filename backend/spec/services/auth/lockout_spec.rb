require "rails_helper"

RSpec.describe Auth::Lockout do
  let(:account) { create(:account) }
  let(:configuration) { account.auth_configuration!.tap { |config| config.update!(lockout_threshold: 3, lockout_duration_minutes: 15) } }
  let(:lockout) { described_class.new(owner: account, configuration: configuration) }

  it "locks after the threshold is reached" do
    3.times { lockout.register_failure("dana@acme.test") }

    expect(lockout.locked?("dana@acme.test")).to be(true)
  end

  it "does not lock below the threshold" do
    2.times { lockout.register_failure("dana@acme.test") }

    expect(lockout.locked?("dana@acme.test")).to be(false)
  end

  it "forgets failures after a successful sign-in" do
    2.times { lockout.register_failure("dana@acme.test") }
    lockout.reset("dana@acme.test")
    lockout.register_failure("dana@acme.test")

    expect(lockout.locked?("dana@acme.test")).to be(false)
  end

  it "unlocks after the lockout duration" do
    3.times { lockout.register_failure("dana@acme.test") }

    travel 16.minutes do
      expect(lockout.locked?("dana@acme.test")).to be(false)
    end
  end

  it "does not affect the same email in another account" do
    3.times { lockout.register_failure("dana@acme.test") }
    other_account = create(:account)

    expect(described_class.new(owner: other_account, configuration: other_account.auth_configuration!).locked?("dana@acme.test")).to be(false)
  end
end
