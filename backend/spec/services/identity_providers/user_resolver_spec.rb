require "rails_helper"

RSpec.describe IdentityProviders::UserResolver do
  subject(:resolver) { described_class.new(provider: provider) }

  let(:project) { create(:project) }
  let(:provider) { create(:identity_provider, project: project) }
  let(:claims) { { "sub" => "google-123", "email" => "Casey@Shop.test", "email_verified" => true, "name" => "Casey Google" } }

  it "signs in the user already linked to the provider's sub" do
    identity = create(:end_user_identity, identity_provider: provider, end_user: create(:end_user, project: project), subject: "google-123")

    expect(resolver.resolve(claims).end_user).to eq(identity.end_user)
    expect(identity.reload.last_sign_in_at).to be_present
  end

  it "creates a verified user without a password when self sign-up is on" do
    end_user = resolver.resolve(claims).end_user

    expect(end_user).to have_attributes(email: "casey@shop.test", name: "Casey Google", password_digest: nil)
    expect(end_user).to be_email_verified
    expect(end_user.identities.sole).to have_attributes(identity_provider: provider, subject: "google-123")
    expect(AuditEvent.last).to have_attributes(action: "end_user.signed_up", target_uid: end_user.uid)
  end

  it "uses the name the app collected when the provider sends none" do
    end_user = resolver.resolve(claims.except("name"), name: "Casey Apple").end_user

    expect(end_user.name).to eq("Casey Apple")
  end

  it "refuses new users when self sign-up is off" do
    project.update!(allow_self_sign_up: false)

    expect { resolver.resolve(claims) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:sign_up_disabled) }
  end

  it "links an existing user whose email is verified" do
    end_user = create(:end_user, project: project, email: "casey@shop.test")

    expect(resolver.resolve(claims).end_user).to eq(end_user)
    expect(end_user.identities.sole.subject).to eq("google-123")
    expect(AuditEvent.last.action).to eq("end_user.identity_linked")
  end

  it "links an invited user and verifies their email" do
    end_user = create(:end_user, :invited, project: project, email: "casey@shop.test")

    resolver.resolve(claims)

    expect(end_user.reload).to be_email_verified
  end

  it "refuses to link a user with a password whose email isn't verified" do
    create(:end_user, :unverified, project: project, email: "casey@shop.test")

    expect { resolver.resolve(claims) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:email_not_verified) }
    expect(EndUserIdentity.count).to eq(0)
  end

  it "refuses emails the provider hasn't verified, whether or not a user has them" do
    create(:end_user, project: project, email: "casey@shop.test")

    [ claims.merge("email_verified" => false), claims.except("email") ].each do |unverified|
      expect { resolver.resolve(unverified) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:provider_email_unverified) }
    end
  end

  it "accepts Apple's email_verified string" do
    expect(resolver.resolve(claims.merge("email_verified" => "true")).end_user).to be_persisted
  end

  it "refuses disabled users" do
    end_user = create(:end_user, project: project, status: "disabled")
    create(:end_user_identity, identity_provider: provider, end_user: end_user, subject: "google-123")

    expect { resolver.resolve(claims) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:user_disabled) }
  end

  it "refuses to link a second account at the same provider" do
    end_user = create(:end_user, project: project, email: "casey@shop.test")
    create(:end_user_identity, identity_provider: provider, end_user: end_user, subject: "google-old")

    expect { resolver.resolve(claims) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:identity_conflict) }
  end
end
