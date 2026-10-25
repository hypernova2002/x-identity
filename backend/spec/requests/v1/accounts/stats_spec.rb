require "rails_helper"
require "openapi_helper"

RSpec.describe "List stats", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:account) { project.account }
  let(:viewer) { create(:user, account: account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
  let(:path_params) { project_path_params(project) }

  def self.project_stats_path(path, summary, tag, schema)
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/#{path}/stats" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get summary do
        tags tag
        security [ { BearerAuth: [] } ]

        response 200, "counts" do
          schema schema
        end
      end
    end
  end

  describe "end users" do
    project_stats_path "end-users", "Count the project's end users by status", "End users", Schemas::EndUserStats

    it "counts them by status, pending invitations and recent sign-ins" do
      create(:end_user, project: project, last_sign_in_at: 2.days.ago)
      create(:end_user, project: project, last_sign_in_at: 40.days.ago)
      create(:end_user, project: project, status: "disabled")
      create(:end_user, :invited, project: project)
      create(:end_user)

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params) do
        expect(parsed_body).to eq("total" => 4, "active" => 3, "disabled" => 1, "invitation_pending" => 1, "signed_in_recently" => 1)
      end
    end
  end

  describe "applications" do
    project_stats_path "applications", "Count the project's applications by kind", "Applications", Schemas::ApplicationStats

    it "counts each kind, leaving out the built-in portal" do
      project.portal_client!
      create_list(:app_client, 2, project: project)
      create(:app_client, :machine, project: project)
      create(:saml_app, project: project)

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params) do
        expect(parsed_body).to eq("total" => 4, "oidc" => 2, "machine" => 1, "saml" => 1)
      end
    end
  end

  describe "groups" do
    project_stats_path "groups", "Count the project's groups", "Groups", Schemas::GroupStats

    it "counts groups and those without members" do
      staff = project.groups.create!(name: "Staff")
      project.groups.create!(name: "Empty")
      GroupMembership.create!(group: staff, end_user: create(:end_user, project: project))

      # The default "All end users" group gains the new end user too, so only "Empty" is empty.
      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params) do
        expect(parsed_body).to eq("total" => 3, "empty" => 1)
      end
    end
  end

  describe "console users" do
    api_path "/v1/accounts/{account_uid}/users/stats" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "Count the account's console users" do
        tags "Users"
        security [ { BearerAuth: [] } ]

        response 200, "counts; pending invitations only for account admins" do
          schema Schemas::UserStats
        end
      end
    end

    let(:admin) { create(:user, :admin, account: account) }

    before do
      create(:user, :owner, account: account)
      create(:user, account: account)
      Invitation.issue!(account: account, invited_by: admin, email: "new@acme.test", role: "member")
    end

    it "counts users, admins and pending invitations for account admins" do
      assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: { account_uid: account.uid }) do
        expect(parsed_body).to eq("total" => 3, "admins" => 2, "pending_invitations" => 1)
      end
    end

    it "leaves invitations out for members" do
      member = account.users.find_by!(role: "member")

      assert_api_response(:get, 200, headers: auth_headers_for(member), path_params: { account_uid: account.uid }) do
        expect(parsed_body).to include("total" => 3, "pending_invitations" => nil)
      end
    end
  end
end
