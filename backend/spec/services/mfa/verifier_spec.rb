require "rails_helper"

RSpec.describe Mfa::Verifier do
  let(:project) { create(:project).tap { |project| project.auth_configuration!.update!(mfa_max_failed_attempts: 3) } }
  let(:end_user) { create(:end_user, :with_mfa, project: project) }
  let(:verifier) { described_class.new(user: end_user) }

  def fail_times(count)
    count.times do
      verifier.verify!("000000")
    rescue ApiError
      nil
    end
  end

  it "accepts the current code" do
    expect(verifier.verify!(current_totp_for(end_user))).to be(true)
  end

  it "rejects a wrong code" do
    expect { verifier.verify!("000000") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_otp) }
  end

  it "disables the user when the limit is reached" do
    fail_times(2)

    expect { verifier.verify!("000000") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:user_disabled) }
  end

  it "signs the disabled user out everywhere" do
    tokens = tokens_for(end_user, app_client: create(:app_client, project: project))
    fail_times(3)

    expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
  end

  it "tells the disabled user by email" do
    expect { fail_times(3) }.to have_enqueued_mail(EndUserMailer, :disabled_after_mfa_failures)
  end

  it "records the disabling in the project's audit log" do
    fail_times(3)

    expect(AuditEvent.where(project: project).pluck(:action)).to include("end_user.disabled_after_mfa_failures")
  end

  it "counts consecutive failures only" do
    fail_times(2)
    verifier.verify!(current_totp_for(end_user))
    fail_times(2)

    expect(end_user.reload).to be_active
  end

  it "clears the count when an admin re-enables the user" do
    fail_times(3)
    end_user.reload.enable!

    expect(end_user.failed_mfa_attempts).to eq(0)
  end
end
