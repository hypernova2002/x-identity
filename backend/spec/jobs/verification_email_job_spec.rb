require "rails_helper"

RSpec.describe VerificationEmailJob do
  let(:account) { create(:account) }

  before { ActionMailer::Base.deliveries.clear }

  it "emails an unverified user" do
    user = create(:user, :unverified, account: account)

    described_class.perform_now(account_id: account.id, email: user.email)

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ user.email ] ])
  end

  it "sends nothing to an already verified user" do
    user = create(:user, account: account)

    described_class.perform_now(account_id: account.id, email: user.email)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends nothing for an unknown email" do
    described_class.perform_now(account_id: account.id, email: "nobody@example.com")

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
