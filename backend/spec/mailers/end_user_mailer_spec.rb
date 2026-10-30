require "rails_helper"

RSpec.describe EndUserMailer do
  let(:project) { create(:project, name: "Shop") }
  let(:end_user) { create(:end_user, project: project, name: nil) }
  let(:device) { DeviceSession.new(device_name: "Chrome on Mac", created_at: Time.utc(2026, 10, 31, 7, 36)) }

  def every_email
    [
      described_class.confirmation(end_user, "123456", "https://shop.test/confirm"),
      described_class.password_reset(end_user, "123456", "https://shop.test/reset"),
      described_class.invitation(end_user, "123456", nil),
      described_class.existing_account(end_user),
      described_class.email_change_code(end_user, "new@shop.test", "123456"),
      described_class.disabled_after_mfa_failures(end_user),
      described_class.new_device_sign_in(end_user, device),
      described_class.email_change_notice(end_user, "new@shop.test")
    ]
  end

  it "writes in English to end users who haven't chosen a language" do
    mail = described_class.confirmation(end_user, "123456", "https://shop.test/confirm")

    expect(mail.subject).to eq("Your Shop verification code")
    expect(mail.body.to_s).to include("Hi,", "Your Shop verification code is:", "123456", "https://shop.test/confirm")
  end

  it "writes in the end user's language" do
    end_user.update!(locale: "ja", name: "Casey")
    mail = described_class.confirmation(end_user, "123456", nil)

    expect(mail.subject).to eq("Shop の確認コード")
    expect(mail.body.to_s).to include("Casey 様", "Shop の確認コードは次のとおりです:", "123456")
    expect(mail.body.to_s).not_to include("リンクを開いて")
  end

  it "writes in the request's language to end users who haven't chosen one" do
    I18n.with_locale(:ja) do
      expect(described_class.existing_account(end_user).subject).to eq("Shop のアカウントはすでに存在します")
    end
  end

  it "sends the email change code to the new address" do
    expect(described_class.email_change_code(end_user, "new@shop.test", "123456").to).to eq([ "new@shop.test" ])
  end

  it "renders every email in each language" do
    HasLocale::LOCALES.each do |locale|
      end_user.update!(locale: locale)

      every_email.each do |mail|
        expect(mail.subject).to include("Shop")
        expect(mail.body.to_s).to be_present
      end
    end
  end
end
