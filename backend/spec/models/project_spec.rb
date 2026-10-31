require "rails_helper"

RSpec.describe Project do
  let(:project) { create(:project) }

  describe "email link templates" do
    it "takes https links with a {token} placeholder, or http on localhost for development" do
      project.assign_attributes(confirm_sign_up_url: "https://shop.example.com/confirm?t={token}", reset_password_url: "http://localhost:3000/reset/{token}")

      expect(project).to be_valid
    end

    it "refuses other schemes and hosts, links without the placeholder, long links and unparseable ones" do
      expect(error_codes(project.tap { |p| p.confirm_sign_up_url = "http://shop.example.com/{token}" }, :confirm_sign_up_url)).to eq([ :not_https_url ])
      expect(error_codes(project.tap { |p| p.confirm_sign_up_url = "https:///{token}" }, :confirm_sign_up_url)).to include(:not_https_url)
      expect(error_codes(project.tap { |p| p.confirm_sign_up_url = "https://shop.example.com/confirm" }, :confirm_sign_up_url)).to eq([ :missing_token_placeholder ])
      expect(error_codes(project.tap { |p| p.confirm_sign_up_url = "https://shop.example.com/#{'a' * 2048}{token}" }, :confirm_sign_up_url)).to eq([ :too_long ])
      expect(error_codes(project.tap { |p| p.confirm_sign_up_url = "https://shop example.com/{token}" }, :confirm_sign_up_url)).to eq([ :invalid_url ])
    end

    it "builds the email's link with the token escaped, or nothing without a template" do
      project.update!(accept_invitation_url: "https://shop.example.com/invite?token={token}")

      expect(project.email_link(:accept_invitation_url, "a b&c")).to eq("https://shop.example.com/invite?token=a+b%26c")
      expect(project.email_link(:reset_password_url, "abc")).to be_nil
    end
  end

  describe "the app portal's client" do
    it "is created once" do
      expect(project.portal_client!).to eq(project.portal_client!)
      expect(project.app_clients.where(system_kind: AppClient::PORTAL).count).to eq(1)
    end

    it "is found when a concurrent request created it first" do
      existing = project.portal_client!
      allow(project.app_clients).to receive(:find_by).and_return(nil)
      allow(project.app_clients).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      expect(project.portal_client!).to eq(existing)
    end
  end

  it "knows when it was deleted, and when its data goes for good" do
    expect([ project.deleted?, project.purge_at ]).to eq([ false, nil ])

    freeze_time do
      project.update!(deleted_at: Time.current)
      expect([ project.deleted?, project.purge_at ]).to eq([ true, Time.current + described_class::RESTORE_PERIOD ])
    end
  end
end
