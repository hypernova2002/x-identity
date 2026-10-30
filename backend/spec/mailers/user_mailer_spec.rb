require "rails_helper"

RSpec.describe UserMailer do
  let(:user) { create(:user, name: "Olive") }
  let(:device) do
    DeviceSession.new(device_name: "Chrome on Mac", city: "Dublin", country_code: "IE", created_ip: "81.17.240.1", created_at: Time.utc(2026, 10, 31, 7, 36))
  end

  def every_email
    [
      described_class.email_verification(user, "token"),
      described_class.password_reset(user, "token"),
      described_class.email_change_confirmation(user, "new@acme.test", "token"),
      described_class.disabled_after_mfa_failures(user),
      described_class.new_device_sign_in(user, device),
      described_class.email_change_notice(user, "new@acme.test")
    ]
  end

  it "writes in English to users who haven't chosen a language" do
    mail = described_class.new_device_sign_in(user, device)

    expect(mail.subject).to eq("New sign-in to your #{user.account.name} account")
    expect(mail.body.to_s).to include("Hi Olive,", "  Location: approximately Dublin, IE", "31 October 2026 at 07:36 UTC")
  end

  it "writes in the user's language" do
    user.update!(locale: "ja")
    mail = described_class.new_device_sign_in(user, device)

    expect(mail.subject).to eq("#{user.account.name} アカウントへの新しいサインイン")
    expect(mail.body.to_s).to include("Olive 様", "  場所: Dublin, IE 付近", "2026年10月31日 07:36 UTC", "「サインイン中の場所」")
  end

  it "writes in the request's language to users who haven't chosen one" do
    I18n.with_locale(:ja) do
      expect(described_class.password_reset(user, "token").subject).to eq("パスワードのリセット")
    end
  end

  it "prefers the user's language to the request's" do
    user.update!(locale: "en")

    I18n.with_locale(:ja) do
      expect(described_class.password_reset(user, "token").subject).to eq("Reset your password")
    end
  end

  it "renders every email in each language" do
    HasLocale::LOCALES.each do |locale|
      user.update!(locale: locale)

      every_email.each do |mail|
        expect(mail.subject).to be_present
        expect(mail.body.to_s).to include("Olive")
      end
    end
  end
end
