require "rails_helper"

RSpec.describe Users::Management do
  let(:account) { create(:account) }
  let(:owner) { create(:user, :owner, account: account) }
  let(:management) { described_class.new(actor: owner) }

  def detail(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.details.first }
  end

  it "refuses roles and statuses that don't exist" do
    member = create(:user, account: account)

    expect(detail { management.update(member, role: "superuser") }).to include(field: "role", code: "inclusion")
    expect(detail { management.update(member, status: "paused") }).to include(field: "status", code: "inclusion")
  end

  it "re-enables a disabled user, recording it, and records nothing when nothing changes" do
    member = create(:user, :disabled, account: account)

    management.update(member, status: "active")
    expect(member.reload).to be_active
    expect(AuditEvent.last).to have_attributes(action: "user.enabled", target_uid: member.uid)

    expect { management.update(member, status: "active", role: "member") }.not_to change(AuditEvent, :count)
  end

  it "lets an owner demote or delete another owner, since the account keeps them" do
    other_owner = create(:user, :owner, account: account)
    management.update(other_owner, role: "admin")
    expect(other_owner.reload).to be_admin

    third_owner = create(:user, :owner, account: account)
    management.destroy(third_owner)
    expect(account.users).not_to include(third_owner)
  end

  it "only lets those allowed delete users" do
    admin = create(:user, :admin, account: account)

    expect { described_class.new(actor: admin).destroy(owner) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:forbidden) }
  end
end
