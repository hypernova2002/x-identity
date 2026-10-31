require "rails_helper"

# Two requests with the same emailed code or link can both find it usable; only the one that
# consumes it first goes ahead. These simulate losing that race.
RSpec.describe "Codes used by two requests at once", type: :request do
  let(:project) { create(:project) }
  let(:password) { "a brand new passphrase" }

  def losing_the_race!
    allow_any_instance_of(OneTimeToken).to receive(:consume!).and_return(false)
  end

  def error_code(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.code }
  end

  before { ActionMailer::Base.deliveries.clear }

  it "doesn't verify an email twice" do
    end_user = create(:end_user, :unverified, project: project)
    EndUsers::Emails.new(project: project).send_confirmation(end_user)
    losing_the_race!

    expect(error_code { EndUsers::Confirmation.new(project: project).confirm(email: end_user.email, code: last_code_sent_to(end_user.email)) }).to eq(:invalid_code)
    expect(end_user.reload).not_to be_email_verified
  end

  it "doesn't reset an end user's password twice" do
    end_user = create(:end_user, project: project)
    EndUsers::Emails.new(project: project).send_password_reset(end_user)
    digest = end_user.password_digest
    losing_the_race!

    expect(error_code { EndUsers::PasswordReset.new(project: project).confirm(email: end_user.email, code: last_code_sent_to(end_user.email), password: password) })
      .to eq(:invalid_code)
    expect(end_user.reload.password_digest).to eq(digest)
  end

  it "doesn't accept an end user's invitation twice" do
    end_user = create(:end_user, :invited, project: project)
    EndUsers::Emails.new(project: project).send_invitation(end_user)
    losing_the_race!

    expect(error_code { EndUsers::InvitationAcceptance.new(project: project).accept(email: end_user.email, code: last_code_sent_to(end_user.email), password: password) })
      .to eq(:invalid_code)
    expect(end_user.reload).not_to be_password_set
  end

  it "doesn't reset a console user's password twice" do
    user = create(:user)
    _record, token = OneTimeToken.issue!(subject: user, purpose: :password_reset)
    losing_the_race!

    expect(error_code { Auth::PasswordReset.new(account: user.account).reset(token: token, password: password) }).to eq(:invalid_token)
  end

  it "doesn't answer a sign-in challenge twice" do
    app_client = create(:app_client, project: project)
    user = create(:end_user, :with_mfa, project: project, email: "mfa@shop.test")
    path = "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth"
    post "#{path}/sign-in", params: { client_id: app_client.uid, email: "mfa@shop.test", password: "correct horse battery staple" }, as: :json
    session = response.parsed_body["session"]
    losing_the_race!

    post "#{path}/respond-to-challenge", params: { client_id: app_client.uid, challenge: "otp", session: session, code: current_totp_for(user) }, as: :json

    expect(response.parsed_body.dig("error", "code")).to eq("invalid_challenge")
  end
end

RSpec.describe EndUsers::PasswordReset do
  it "lets an end user with passkeys use them again only after signing in with the new password" do
    project = create(:project)
    end_user = create(:end_user, project: project)
    WebauthnCredential.create!(subject: end_user, external_id: "cred-1", public_key: "key", rp_id: "login.acme.com", name: "Passkey")
    EndUsers::Emails.new(project: project).send_password_reset(end_user)

    described_class.new(project: project).confirm(email: end_user.email, code: last_code_sent_to(end_user.email), password: "a brand new passphrase")

    expect(end_user.reload.passkey_recovery_until).to be_future
  end
end

RSpec.describe EndUsers::Confirmation do
  it "sends nothing to addresses that are already confirmed, or unknown" do
    project = create(:project)
    verified = create(:end_user, project: project)
    ActionMailer::Base.deliveries.clear

    described_class.new(project: project).deliver(email: verified.email)
    described_class.new(project: project).deliver(email: "nobody@shop.test")

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
