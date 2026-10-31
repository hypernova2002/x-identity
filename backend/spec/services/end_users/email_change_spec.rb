require "rails_helper"

RSpec.describe EndUsers::EmailChange do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }
  let(:end_user) { create(:end_user, project: project, email: "casey@shop.test") }
  let(:change) { described_class.new(end_user: end_user, ip: "203.0.113.10") }
  let(:password) { "correct horse battery staple" }

  def requested_code
    change.deliver(new_email: "casey@new.test")
    ActionMailer::Base.deliveries.find { |mail| mail.to == [ "casey@new.test" ] }.body.to_s[/\b\d{6}\b/]
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "asking for the change" do
    it "checks the password, then leaves the address check to a job so the answer never reveals it" do
      expect { change.request(new_email: "casey@new.test", current_password: password) }
        .to have_enqueued_job(EndUserEmailChangeJob).with(hash_including(end_user_id: end_user.id, new_email: "casey@new.test"))

      expect { change.request(new_email: "casey@new.test", current_password: "wrong") }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "current_password", code: "incorrect") }
    end

    it "refuses the address the user already has" do
      expect { change.request(new_email: "casey@shop.test", current_password: password) }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "new_email", code: "same_as_current_email") }
    end

    it "needs an MFA code from users who have MFA on" do
      user = create(:end_user, :with_mfa, project: project)
      mfa_change = described_class.new(end_user: user)

      expect { mfa_change.request(new_email: "new@shop.test", current_password: password, otp_code: "000000") }
        .to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_otp) }
      expect { mfa_change.request(new_email: "new@shop.test", current_password: password, otp_code: current_totp_for(user)) }
        .to have_enqueued_job(EndUserEmailChangeJob)
    end
  end

  describe "sending the code" do
    it "emails a code to the new address and a notice to the old one" do
      change.deliver(new_email: "casey@new.test")

      expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([ "casey@new.test" ], [ "casey@shop.test" ])
      expect(AuditEvent.last).to have_attributes(action: "end_user.email_change_requested", metadata: { "new_email" => "casey@new.test" })
    end

    it "sends nothing when another end user has the address, and records why" do
      create(:end_user, project: project, email: "taken@shop.test")

      change.deliver(new_email: "taken@shop.test")

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(AuditEvent.last).to have_attributes(action: "end_user.email_change_blocked", metadata: { "new_email" => "taken@shop.test", "reason" => "email_taken" })
    end

    it "is skipped by the job for users who have since been disabled or deleted" do
      end_user.update!(status: "disabled")

      EndUserEmailChangeJob.perform_now(end_user_id: end_user.id, new_email: "casey@new.test")
      EndUserEmailChangeJob.perform_now(end_user_id: 0, new_email: "casey@new.test")

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "confirming" do
    it "changes and verifies the address, signing out every other session" do
      code = requested_code
      app_client = create(:app_client, project: project)
      kept, = signed_in_device(end_user, app_client: app_client)
      other, = signed_in_device(end_user, app_client: app_client)

      change.confirm(code: code, keep_session_id: kept.uid)

      expect(end_user.reload).to have_attributes(email: "casey@new.test", email_verified?: true)
      expect([ kept.reload.revoked_at, other.reload.revoked_at.present? ]).to eq([ nil, true ])
      expect(AuditEvent.last).to have_attributes(action: "end_user.email_changed", metadata: { "old_email" => "casey@shop.test", "new_email" => "casey@new.test" })
    end

    it "refuses a wrong code, or no pending change" do
      expect { change.confirm(code: "123456", keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_code) }

      requested_code
      expect { change.confirm(code: "000000", keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_code) }
      expect(end_user.reload.email).to eq("casey@shop.test")
    end

    it "uses each code once" do
      code = requested_code
      change.confirm(code: code, keep_session_id: nil)

      expect { change.confirm(code: code, keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_code) }
    end

    it "refuses when someone took the address after the code was sent" do
      code = requested_code
      create(:end_user, project: project, email: "casey@new.test")

      expect { change.confirm(code: code, keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:email_taken) }
    end

    it "refuses when the address is taken at the same moment, by the database's unique index" do
      code = requested_code
      allow(end_user).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)

      expect { change.confirm(code: code, keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:email_taken) }
    end

    it "refuses when a concurrent confirmation used the code first" do
      code = requested_code
      allow(OneTimeToken).to receive(:current_for).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap { |record| allow(record).to receive(:consume!).and_return(false) }
      end

      expect { change.confirm(code: code, keep_session_id: nil) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_code) }
      expect(end_user.reload.email).to eq("casey@shop.test")
    end
  end
end
