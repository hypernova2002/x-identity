require "rails_helper"

RSpec.describe AuthConfigurations::Update do
  let(:account) { create(:account) }
  let(:owner) { create(:user, :owner, account: account) }

  it "checks rules across settings against what's stored, not a copy loaded before another request's change" do
    stale = account.auth_configuration!
    AuthConfiguration.where(id: stale.id).update_all(mfa_requirement: "off")

    expect { described_class.new(actor: owner, owner: account).call(passkeys: "required") }
      .to raise_error(ApiError) { |error| expect(error.details.sole[:field]).to eq("passkeys") }
  end
end
