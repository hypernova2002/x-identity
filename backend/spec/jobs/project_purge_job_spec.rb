require "rails_helper"

RSpec.describe ProjectPurgeJob do
  let(:project) { create(:project) }

  def populate(project)
    end_user = create(:end_user, :with_mfa, project: project)
    app = create(:app_client, project: project)
    Auth::TokenIssuer.new(realm: project.realm, app_client: app).issue(user: end_user, authenticated_at: Time.current, amr: [ "pwd" ])
    BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)
    machine = create(:app_client, :machine, project: project)
    machine.api_grants.create!(api_resource: project.api_resources.create!(name: "Orders", identifier: "https://#{SecureRandom.hex(3)}.example.com"), scopes: [])
    create(:identity_provider, :saml, project: project)
    create(:saml_app, project: project)
    project.realm.recorder.record(action: "end_user.signed_in", actor: end_user)
  end

  it "purges every row of a project deleted over 24 hours ago, keeping its audit events" do
    populate(project)
    kept = create(:project, account: project.account).tap { |other| populate(other) }
    project.update!(deleted_at: 25.hours.ago)

    described_class.perform_now(project_id: project.id)

    expect(Project.exists?(project.id)).to be(false)
    expect(RefreshToken.count).to eq(1)
    expect([ EndUser, AppClient, BrowserSession, DeviceSession, ApiResource, IdentityProvider, SamlApp, Group ].map { |model| model.where(project_id: project.id).count }.sum).to eq(0)
    expect(AuditEvent.where(project_id: project.id).count).to be >= 1
    expect(AuditEvent.last).to have_attributes(action: "project.purged", target_uid: project.uid)
    expect(kept.end_users.count).to eq(1)
  end

  it "leaves projects alone within the restore period, or once restored" do
    project.update!(deleted_at: 1.hour.ago)
    described_class.perform_now(project_id: project.id)
    expect(Project.exists?(project.id)).to be(true)

    project.update!(deleted_at: nil)
    travel(2.days) { described_class.perform_now(project_id: project.id) }
    expect(Project.exists?(project.id)).to be(true)
  end

  it "deletes in batches, finishing what's left if run again" do
    stub_const("Projects::Purge::BATCH", 2)
    3.times { create(:end_user, project: project) }
    project.update!(deleted_at: 25.hours.ago)

    described_class.perform_now(project_id: project.id)

    expect(EndUser.where(project_id: project.id).count).to eq(0)
  end
end

RSpec.describe PurgeDeletedProjectsJob do
  it "queues purges for deleted projects past their restore period" do
    due = create(:project, deleted_at: 25.hours.ago)
    create(:project, deleted_at: 1.hour.ago)
    create(:project)

    expect { described_class.perform_now }.to have_enqueued_job(ProjectPurgeJob).with(project_id: due.id).exactly(:once)
  end
end
