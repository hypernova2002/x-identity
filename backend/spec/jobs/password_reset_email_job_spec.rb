require "rails_helper"

RSpec.describe PasswordResetEmailJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before { ActionMailer::Base.deliveries.clear }

  it "emails a reset link to an active user" do
    described_class.perform_now(account_id: account.id, email: user.email)

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ user.email ] ])
  end

  it "sends nothing for an unknown email" do
    described_class.perform_now(account_id: account.id, email: "nobody@example.com")

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends nothing to a disabled user" do
    user.update!(status: "disabled")

    described_class.perform_now(account_id: account.id, email: user.email)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "does not look up users in other accounts" do
    described_class.perform_now(account_id: create(:account).id, email: user.email)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "records the requester's IP in the audit log" do
    described_class.perform_now(account_id: account.id, email: user.email, ip: "203.0.113.7", user_agent: "Spec")

    expect(account.audit_events.last).to have_attributes(action: "user.password_reset_requested", ip: "203.0.113.7")
  end
end
