require "rails_helper"

RSpec.describe "Sign-up and refresh edge cases" do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }

  def error(&block)
    expect(&block).to raise_error(ApiError) { |raised| return raised }
  end

  describe EndUsers::SignUp do
    let(:sign_up) { described_class.new(project: project) }
    let(:digest) { Passwords::Hasher.new.digest("correct horse battery staple") }

    before { ActionMailer::Base.deliveries.clear }

    it "queues a sign-up without an app client, from the API's own sign-up" do
      expect { sign_up.call(email: "new@shop.test", password: "correct horse battery staple") }
        .to have_enqueued_job(EndUserSignUpJob).with(hash_including(app_client_id: nil, email: "new@shop.test"))
    end

    it "treats a user created at the same moment as existing, and reminds them" do
      existing = create(:end_user, project: project, email: "new@shop.test")
      allow(project.end_users).to receive(:find_by).and_return(nil)
      allow(project).to receive(:end_users).and_return(project.end_users)
      allow(project.end_users).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      allow(project.end_users).to receive(:find_by!).with(email: "new@shop.test").and_return(existing)

      sign_up.deliver(email: "new@shop.test", name: nil, password_digest: digest, custom_attributes: {})

      expect(ActionMailer::Base.deliveries.sole.subject).to include("already have")
    end

    it "sends nothing to a disabled user signing up again, but records it" do
      create(:end_user, project: project, email: "new@shop.test", status: "disabled")

      sign_up.deliver(email: "new@shop.test", name: nil, password_digest: digest, custom_attributes: {})

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(AuditEvent.last).to have_attributes(action: "end_user.sign_up_repeated")
    end
  end

  describe Accounts::SignUp do
    let(:sign_up) { described_class.new }

    it "says the alias is taken when another sign-up claimed it at the same moment" do
      allow(Account).to receive(:new).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap { |account| allow(account).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) }
      end

      raised = error { sign_up.call(account_name: "Acme", slug: "acme-race", name: "Olive", email: "olive@acme.test", password: "correct horse battery staple") }

      expect(raised.details.first).to include(field: "slug", code: "taken")
    end

    it "reports the user's problems alongside the account's" do
      raised = error { sign_up.call(account_name: "", slug: "acme-bad", name: "", email: "not-an-email", password: "short") }

      expect(raised.details.pluck(:field)).to include("account_name", "name", "email", "password")
    end
  end

  describe Auth::Refresh do
    it "ends the session once the refresh token has expired" do
      user = create(:user)
      refresh_token = tokens_for(user).refresh_token
      RefreshToken.update_all(expires_at: 1.minute.ago)

      expect(error { described_class.new(realm: user.realm).call(refresh_token: refresh_token) }.code).to eq(:session_expired)
    end
  end
end
