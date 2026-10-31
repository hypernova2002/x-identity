require "rails_helper"

RSpec.describe "Project management edge cases" do
  let(:project) { create(:project) }
  let(:account) { project.account }
  let(:admin) { create(:user, :admin, account: account) }

  def raised(&block)
    expect(&block).to raise_error(ApiError) { |error| return error }
  end

  describe Projects::Management do
    let(:management) { described_class.new(actor: admin) }

    it "refuses an invalid name, and members creating or restoring projects" do
      expect(raised { management.create(name: "") }.code).to eq(:validation_failed)
      expect(raised { management.update(project, name: "") }.code).to eq(:validation_failed)

      member = described_class.new(actor: create(:user, account: account))
      expect(raised { member.create(name: "Staging") }.code).to eq(:forbidden)
      project.reload.update!(deleted_at: Time.current)
      expect(raised { member.restore(project) }.code).to eq(:forbidden)
    end

    it "records nothing when the settings didn't change" do
      expect { management.update(project, name: project.name) }.not_to change(AuditEvent, :count)
    end
  end

  describe Projects::MembershipManagement do
    let(:management) { described_class.new(actor: admin, project: project) }
    let(:user) { create(:user, account: account) }

    it "refuses adding someone twice, and roles that don't exist" do
      management.add(user_uid: user.uid, role: "viewer")

      expect(raised { management.add(user_uid: user.uid, role: "viewer") }).to have_attributes(code: :conflict, reason: :already_project_member)
      expect(raised { management.add(user_uid: create(:user, account: account).uid, role: "owner") }.code).to eq(:validation_failed)
      expect(raised { management.update(project.project_memberships.find_by!(user: user), role: "owner") }.code).to eq(:validation_failed)
    end
  end

  describe AppClients::Management do
    let(:management) { described_class.new(actor: admin, project: project) }

    it "clears a launch URL sent blank, and records nothing when nothing changed" do
      app_client = create(:app_client, project: project, launch_url: "https://shop.example.com")

      management.update(app_client, launch_url: "")
      expect(app_client.reload.launch_url).to be_nil
      expect { management.update(app_client, name: app_client.name) }.not_to change(AuditEvent, :count)
    end
  end

  it "records nothing for group, attribute and authentication settings updates that change nothing" do
    group = create(:group, project: project, name: "Staff")
    definition = project.end_user_attribute_definitions.create!(key: "plan", label: "Plan", data_type: "string")

    expect do
      Groups::Management.new(actor: admin, project: project).update(group, name: "Staff")
      AttributeDefinitions::Management.new(actor: admin, project: project).update(definition, label: "Plan")
      AuthConfigurations::Update.new(actor: admin, owner: project).call(lockout_threshold: project.auth_configuration!.lockout_threshold)
    end.not_to change(AuditEvent, :count)
  end

  it "only lets those who manage app clients change who can use them" do
    viewer = create(:user, account: account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") }
    app_client = create(:app_client, project: project)

    expect(raised { Apps::Assignments.new(actor: viewer, project: project).assign(app_client, create(:end_user, project: project)) }.code).to eq(:forbidden)
  end

  it "filters applications by whether they're machine-to-machine" do
    create(:app_client, project: project, name: "Web")
    create(:app_client, :machine, project: project, name: "Billing")

    names = ->(value) { Apps::Directory.new(project, ActionController::Parameters.new(q: { machine_eq: value })).map(&:name) }
    expect(names.("true")).to eq([ "Billing" ])
    expect(names.("false")).to eq([ "Web" ])
  end

  describe EndUsers::Profile do
    it "refuses an invalid name, changing nothing" do
      end_user = create(:end_user, project: project)

      expect(raised { described_class.new(end_user: end_user).update(name: "n" * 101) }.code).to eq(:validation_failed)
      expect(end_user.reload.name).to eq("Casey Customer")
    end
  end
end
