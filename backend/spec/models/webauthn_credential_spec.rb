require "rails_helper"

RSpec.describe WebauthnCredential do
  it "says what signing in with it proves: the kind of key, and that the user unlocked it" do
    expect(described_class.new(backup_eligible: false).amr).to eq(%w[hwk user])
    expect(described_class.new(backup_eligible: true).amr).to eq(%w[swk user])
  end
end
