require "rails_helper"

RSpec.describe EmailChangeEmailJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, email: "old@acme.test") }

  before { ActionMailer::Base.deliveries.clear }

  it "sends the confirmation to the new address and a notice to the old one" do
    described_class.perform_now(user_id: user.id, new_email: "new@acme.test")

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([ "new@acme.test" ], [ "old@acme.test" ])
  end

  context "when the new address belongs to another user in the account" do
    before { create(:user, account: account, email: "new@acme.test") }

    it "sends nothing" do
      described_class.perform_now(user_id: user.id, new_email: "new@acme.test")

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "records the blocked attempt in the audit log" do
      described_class.perform_now(user_id: user.id, new_email: "new@acme.test")

      expect(account.audit_events.last).to have_attributes(action: "user.email_change_blocked", metadata: hash_including("reason" => "email_taken"))
    end
  end

  it "allows an address that is only used in another account" do
    create(:user, email: "new@acme.test")

    described_class.perform_now(user_id: user.id, new_email: "new@acme.test")

    expect(ActionMailer::Base.deliveries.map(&:to)).to include([ "new@acme.test" ])
  end
end
