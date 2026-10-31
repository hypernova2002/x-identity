require "rails_helper"

# Rules that are each a line or two in their model.
RSpec.describe "Model rules" do
  let(:project) { create(:project) }

  it "keeps app assignments within one project" do
    app = create(:app_client, project: project)

    expect(error_codes(AppAssignment.new(project: project, app: app, principal: create(:end_user)), :principal)).to eq([ :other_project ])
    expect(error_codes(AppAssignment.new(project: project, app: app), :principal)).not_to include(:other_project)
  end

  it "keeps project members to the project's account" do
    expect(error_codes(ProjectMembership.new(project: project, user: create(:user), role: "viewer"), :user)).to eq([ :other_account ])
  end

  it "limits attributes per project" do
    stub_const("EndUserAttributeDefinition::MAX_PER_PROJECT", 1)
    project.end_user_attribute_definitions.create!(key: "plan", label: "Plan", data_type: "string")

    expect(error_codes(project.end_user_attribute_definitions.new(key: "seats", label: "Seats", data_type: "number"), :base)).to eq([ :too_many_attributes ])
  end

  it "limits passkeys per user" do
    stub_const("WebauthnCredential::MAX_PER_USER", 1)
    user = create(:end_user, project: project)
    attributes = { subject: user, public_key: "key", rp_id: "login.acme.com", name: "Passkey" }
    WebauthnCredential.create!(external_id: "cred-1", **attributes)

    expect(error_codes(WebauthnCredential.new(external_id: "cred-2", **attributes), :base)).to eq([ :too_many_passkeys ])
  end

  it "needs a verified custom domain to put a SAML app on it" do
    app = build(:saml_app, project: project, on_custom_domain: true)
    expect(error_codes(app, :on_custom_domain)).to eq([ :needs_custom_domain ])

    project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
    expect(app).to be_valid
  end

  it "keeps the first revocation time when revoked again" do
    end_user = create(:end_user, project: project)
    session, = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
    secret, = AppClientSecret.issue!(create(:app_client, :confidential, project: project))
    records = [ session, session.device_session, secret ]

    records.each(&:revoke!)
    first = records.map { |record| record.reload.revoked_at }
    travel(1.minute) { records.each(&:revoke!) }

    expect(records.map { |record| record.reload.revoked_at }).to eq(first)
  end

  it "doesn't find a browser session for a user disabled since" do
    end_user = create(:end_user, project: project)
    _session, token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
    end_user.update!(status: "disabled")

    expect(BrowserSession.find_valid(token, project: project)).to be_nil
    expect(BrowserSession.find_valid("unknown", project: project)).to be_nil
  end

  it "asks for a lowercase letter when the project requires one" do
    configuration = project.auth_configuration!
    configuration.password_require_lowercase = true

    expect(configuration.password_violations("ALL CAPS PASSWORD").pluck(:code)).to include("needs_lowercase")
    expect(configuration.password_violations("Has lowercase letters").pluck(:code)).not_to include("needs_lowercase")
  end
end
