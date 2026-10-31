require "rails_helper"

RSpec.describe EndUserEmailJob do
  let(:project) { create(:project, accept_invitation_url: "https://shop.example.com/invite?token={token}") }
  let(:invited) { create(:end_user, :invited, project: project, email: "new@shop.test") }

  before { ActionMailer::Base.deliveries.clear }

  it "emails an invitation with a code and the project's own link" do
    described_class.perform_now(kind: "invitation", end_user_id: invited.id)

    mail = ActionMailer::Base.deliveries.sole
    expect(mail.to).to eq([ "new@shop.test" ])
    expect(mail.body.to_s).to match(/\b\d{6}\b/).and include("https://shop.example.com/invite?token=")
  end

  it "doesn't invite someone who has set a password since, or who is disabled or gone" do
    password_set = create(:end_user, project: project)
    invited.update!(status: "disabled")

    [ password_set.id, invited.id, 0 ].each { |id| described_class.perform_now(kind: "invitation", end_user_id: id) }

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "refuses kinds it doesn't know" do
    expect { described_class.perform_now(kind: "newsletter", end_user_id: create(:end_user, project: project).id) }.to raise_error(ArgumentError, /newsletter/)
  end
end
