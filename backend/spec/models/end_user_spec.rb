require "rails_helper"

RSpec.describe EndUser do
  let(:project) { create(:project) }
  let!(:verified) { create(:end_user, project: project) }
  let!(:unverified) { create(:end_user, :unverified, project: project) }
  let!(:with_mfa) { create(:end_user, :with_mfa, project: project) }

  it "filters by verified email from the request's true or false, ignoring anything else" do
    expect(project.end_users.with_verified_email("true")).to contain_exactly(verified, with_mfa)
    expect(project.end_users.with_verified_email("false")).to contain_exactly(unverified)
    expect(project.end_users.with_verified_email("maybe")).to contain_exactly(verified, unverified, with_mfa)
  end

  it "filters by MFA the same way" do
    expect(project.end_users.with_mfa("true")).to contain_exactly(with_mfa)
    expect(project.end_users.with_mfa("false")).to contain_exactly(verified, unverified)
    expect(project.end_users.with_mfa("")).to contain_exactly(verified, unverified, with_mfa)
  end

  it "keeps custom attributes as an object" do
    expect(error_codes(build(:end_user, custom_attributes: [ "a" ]), :custom_attributes)).to eq([ :not_an_object ])
  end
end
