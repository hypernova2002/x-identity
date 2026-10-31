require "rails_helper"

# Email jobs run after the request; whatever they were about may have been deleted by then.
RSpec.describe "Email jobs for records deleted before they run" do
  before { ActionMailer::Base.deliveries.clear }

  it "send nothing and don't fail" do
    EndUserLookupEmailJob.perform_now(kind: "password_reset", project_id: 0, email: "casey@shop.test")
    EndUserSignUpJob.perform_now(project_id: 0, email: "casey@shop.test", password_digest: "digest")
    EmailChangeEmailJob.perform_now(user_id: 0, new_email: "new@acme.test")
    PasswordResetEmailJob.perform_now(account_id: 0, email: "olive@acme.test")
    VerificationEmailJob.perform_now(account_id: 0, email: "olive@acme.test")
    NewDeviceEmailJob.perform_now(device_session_id: 0)
    EndUserEmailChangeJob.perform_now(end_user_id: 0, new_email: "new@shop.test")

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "refuse lookup kinds they don't know" do
    expect { EndUserLookupEmailJob.perform_now(kind: "newsletter", project_id: create(:project).id, email: "casey@shop.test") }
      .to raise_error(ArgumentError, /newsletter/)
  end

  it "send the end user's email change code for a user still active" do
    end_user = create(:end_user)

    EndUserEmailChangeJob.perform_now(end_user_id: end_user.id, new_email: "new@shop.test")

    expect(ActionMailer::Base.deliveries.map(&:to)).to include([ "new@shop.test" ])
  end
end
