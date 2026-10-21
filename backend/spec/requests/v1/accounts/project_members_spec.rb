require "rails_helper"
require "openapi_helper"

RSpec.describe "Project members", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:member) { create(:user, account: account) }
  let(:project) { create(:project, account: account) }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/members" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List project members" do
        tags "Projects"
        security [ { BearerAuth: [] } ]

        response 200, "members" do
          schema type: :array, items: Schemas::ProjectMember
        end
      end

      post "Add a user to the project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ProjectMembers::CreateRequest.as_schema } }

        response 201, "added" do
          schema Schemas::ProjectMember
        end

        response 409, "already a member" do
          schema Schemas::Error
        end

        response 422, "unknown user or invalid role" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { { account_uid: account.uid, project_uid: project.uid } }

    it "adds a user from the same account" do
      assert_api_response :post, 201, headers: auth_headers_for(admin), body: { user_uid: member.uid, role: "developer" }, path_params: path_params
    end

    it "refuses users from another account" do
      outsider = create(:user)

      assert_api_response :post, 422, headers: auth_headers_for(admin), body: { user_uid: outsider.uid, role: "developer" }, path_params: path_params
    end

    it "refuses an invalid role" do
      assert_api_response :post, 422, headers: auth_headers_for(admin), body: { user_uid: member.uid, role: "superuser" }, path_params: path_params
    end

    it "lists members" do
      create(:project_membership, project: project, user: member)

      assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: path_params) do
        expect(parsed_body.pluck("user_uid")).to eq([ member.uid ])
      end
    end
  end

  describe "a single member" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/members/{user_uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :user_uid, in: :path, required: true, schema: { type: :string }

      patch "Change a member's project role" do
        tags "Projects"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ProjectMembers::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::ProjectMember
        end

        response 403, "not a project or account admin" do
          schema Schemas::Error
        end
      end

      delete "Remove a member from the project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]

        response 204, "removed"
      end
    end

    let!(:membership) { create(:project_membership, project: project, user: member, role: "viewer") }
    let(:path_params) { { account_uid: account.uid, project_uid: project.uid, user_uid: member.uid } }

    it "changes the role" do
      assert_api_response :patch, 200, headers: auth_headers_for(admin), body: { role: "admin" }, path_params: path_params

      expect(membership.reload).to be_admin
    end

    it "does not let viewers change roles" do
      assert_api_response :patch, 403, headers: auth_headers_for(member), body: { role: "admin" }, path_params: path_params
    end

    it "removes the member" do
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params

      expect(ProjectMembership.exists?(membership.id)).to be(false)
    end
  end
end
