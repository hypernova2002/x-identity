require "rails_helper"

RSpec.describe "Recording audit events" do
  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }

  it "doesn't keep a change whose audit event couldn't be written" do
    allow(AuditEvent).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)

    expect { Groups::Management.new(actor: admin, project: project).create(name: "Staff") }.to raise_error(ActiveRecord::StatementInvalid)
    expect(project.groups.exists?(name: "Staff")).to be(false)
  end

  it "keeps a failure's event even though the request fails" do
    user = create(:user, :with_mfa, account: project.account)

    expect { Mfa::Verifier.new(user: user).verify!("000000") }.to raise_error(ApiError)
    expect(AuditEvent.where(action: "user.mfa_failed", actor_uid: user.uid)).to exist
  end
end
