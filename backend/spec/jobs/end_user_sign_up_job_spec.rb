require "rails_helper"

RSpec.describe EndUserSignUpJob do
  let(:project) { create(:project) }
  let(:digest) { Passwords::Hasher.new.digest("a new password here") }

  before { ActionMailer::Base.deliveries.clear }

  def perform(email: "casey@shop.test")
    described_class.perform_now(project_id: project.id, email: email, name: "Casey", password_digest: digest, custom_attributes: { "plan" => "pro" })
  end

  context "with a new email" do
    it "creates an unverified end user" do
      perform

      expect(project.end_users.find_by!(email: "casey@shop.test")).to have_attributes(email_verified?: false, custom_attributes: { "plan" => "pro" })
    end

    it "emails a 6-digit confirmation code" do
      perform

      expect(last_code_sent_to("casey@shop.test")).to match(/\A\d{6}\z/)
    end
  end

  context "when the email belongs to an unconfirmed end user" do
    let!(:existing) { create(:end_user, :unverified, project: project, email: "casey@shop.test", password: "the original password") }

    it "sends a fresh confirmation code" do
      perform

      expect(last_code_sent_to("casey@shop.test")).to be_present
    end

    it "keeps the original password" do
      perform

      expect(Passwords::Hasher.new.matches?("the original password", existing.reload.password_digest)).to be(true)
    end
  end

  context "when the email belongs to a confirmed end user" do
    let!(:existing) { create(:end_user, project: project, email: "casey@shop.test") }

    it "tells them they already have an account" do
      perform

      expect(ActionMailer::Base.deliveries.map(&:subject)).to eq([ "You already have a #{project.name} account" ])
    end

    it "changes nothing about the account" do
      expect { perform }.not_to(change { existing.reload.attributes })
    end
  end

  it "treats the same email in another project as new" do
    create(:end_user, email: "casey@shop.test")

    expect { perform }.to change(project.end_users, :count).by(1)
  end
end
