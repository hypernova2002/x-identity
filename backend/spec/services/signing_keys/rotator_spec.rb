require "rails_helper"

RSpec.describe SigningKeys::Rotator do
  let(:account) { create(:account) }
  let(:configuration) { account.auth_configuration! }
  let(:rotator) { described_class.new(owner: account, configuration: configuration) }

  it "creates a key with the configured algorithm" do
    expect(rotator.current.algorithm).to eq("ES256")
  end

  it "keeps using the same key until rotation is due" do
    expect(rotator.current).to eq(rotator.current)
  end

  it "rotates once the key is older than the rotation period" do
    key = rotator.current

    travel (configuration.signing_key_rotation_days + 1).days do
      expect(rotator.current).not_to eq(key)
    end
  end

  it "rotates when the configured algorithm changes" do
    rotator.current
    configuration.update!(signing_algorithm: "PS256")

    expect(rotator.current.algorithm).to eq("PS256")
  end

  it "keeps publishing a retired key long enough for its tokens to expire" do
    key = rotator.current
    configuration.update!(signing_algorithm: "RS256")
    rotator.current

    travel AuthConfiguration::MAX_ACCESS_TOKEN_TTL_MINUTES.minutes do
      expect(account.signing_keys.published).to include(key)
    end
  end

  it "keys are never shared between accounts" do
    other_account = create(:account)
    other_key = described_class.new(owner: other_account, configuration: other_account.auth_configuration!).current

    expect(rotator.current).not_to eq(other_key)
  end
end
