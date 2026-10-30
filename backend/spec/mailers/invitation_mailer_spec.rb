require "rails_helper"

RSpec.describe InvitationMailer do
  let(:account) { create(:account, name: "Acme") }
  let(:inviter) { create(:user, :admin, account: account, name: "Olive") }
  let(:invitation) do
    travel_to(Time.utc(2026, 10, 24)) { Invitation.issue!(account: account, invited_by: inviter, email: "new@acme.test", role: "admin").first }
  end

  it "writes in English by default" do
    mail = described_class.invitation(invitation, "token")

    expect(mail.subject).to eq("You've been invited to Acme on x-identity")
    expect(mail.body.to_s).to include("Olive invited you to join the Acme account on x-identity with the admin role.")
  end

  it "writes in the inviter's language, since the person invited hasn't chosen one" do
    mail = I18n.with_locale(:ja) { described_class.invitation(invitation, "token").message }

    expect(mail.subject).to eq("x-identity の Acme に招待されました")
    expect(mail.body.to_s).to include("Olive から", "管理者の役割", "#{I18n.l(invitation.expires_at.to_date, format: :email, locale: :ja)} (UTC)")
  end

  it "prefers the inviter's chosen language to the request's" do
    inviter.update!(locale: "en")

    mail = I18n.with_locale(:ja) { described_class.invitation(invitation, "token").message }

    expect(mail.subject).to eq("You've been invited to Acme on x-identity")
  end
end
