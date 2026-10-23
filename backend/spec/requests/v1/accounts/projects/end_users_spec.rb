require "rails_helper"
require "openapi_helper"

RSpec.describe "End users (admin)", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List and search the project's end users" do
        tags "End users"
        security [ { BearerAuth: [] } ]
        parameter name: :q, in: :query, style: :deepObject, explode: true, schema: {
          type: :object,
          properties: { email_cont: { type: :string }, name_cont: { type: :string }, status_eq: { type: :string }, uid_eq: { type: :string } }
        }
        parameter name: :filter, in: :query, style: :deepObject, explode: true, schema: {
          type: :object,
          properties: {
            email_verified: { type: :string, enum: %w[true false] },
            mfa: { type: :string, enum: %w[true false] },
            invitation_pending: { type: :string, enum: %w[true] },
            group_uid: { type: :string }
          }
        }

        response 200, "end users, paginated with Total, Per-Page and Link headers" do
          schema type: :array, items: Schemas::EndUser
        end
      end

      post "Create an end user and invite them to set a password" do
        tags "End users"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUsers::CreateRequest.as_schema } }

        response 201, "created" do
          schema Schemas::EndUser
        end

        response 403, "only project admins and developers can manage end users" do
          schema Schemas::Error
        end

        response 409, "an end user with this email already exists" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { project_path_params(project) }

    it "searches by email" do
      create(:end_user, project: project, email: "casey@shop.test")
      create(:end_user, project: project, email: "robin@shop.test")

      assert_api_response :get, 200, headers: auth_headers_for(viewer), params: { q: { email_cont: "casey" } }, path_params: path_params do
        expect(parsed_body.pluck("email")).to eq([ "casey@shop.test" ])
      end
    end

    it "creates an invited end user and queues the invitation" do
      expect { assert_api_response :post, 201, headers: auth_headers_for(admin), body: { email: "new@shop.test" }, path_params: path_params }
        .to have_enqueued_job(EndUserEmailJob).with(kind: "invitation", end_user_id: kind_of(Integer))
    end

    it "marks the new end user's invitation as pending" do
      assert_api_response(:post, 201, headers: auth_headers_for(admin), body: { email: "new@shop.test" }, path_params: path_params) do
        expect(parsed_body["invitation_pending"]).to be(true)
      end
    end

    it "lets admins set attributes end users can't" do
      create(:end_user_attribute_definition, project: project, key: "tier", user_editable: false)

      assert_api_response :post, 201, headers: auth_headers_for(admin), body: { email: "new@shop.test", custom_attributes: { tier: "gold" } },
        path_params: path_params
    end

    it "refuses a duplicate email" do
      create(:end_user, project: project, email: "new@shop.test")

      assert_api_response :post, 409, headers: auth_headers_for(admin), body: { email: "new@shop.test" }, path_params: path_params
    end

    it "does not let viewers create end users" do
      assert_api_response :post, 403, headers: auth_headers_for(viewer), body: { email: "new@shop.test" }, path_params: path_params
    end
  end

  describe "filtering the directory" do
    let(:project) { create(:project) }
    let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
    let!(:verified) { create(:end_user, project: project, email: "verified@shop.test") }
    let!(:unverified) { create(:end_user, :unverified, project: project, email: "unverified@shop.test") }
    let!(:with_mfa) { create(:end_user, :with_mfa, project: project, email: "mfa@shop.test") }
    let!(:invited) { create(:end_user, :invited, project: project, email: "invited@shop.test") }

    def emails_for(query)
      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/end-users", params: query, headers: auth_headers_for(viewer)
      response.parsed_body.map { |user| user["email"] }
    end

    it "filters by email verification, MFA and pending invitations" do
      expect(emails_for(filter: { email_verified: "false" })).to contain_exactly("unverified@shop.test", "invited@shop.test")
      expect(emails_for(filter: { mfa: "true" })).to eq([ "mfa@shop.test" ])
      expect(emails_for(filter: { invitation_pending: "true" })).to eq([ "invited@shop.test" ])
    end

    it "filters by group and finds users by uid" do
      group = create(:group, project: project)
      group.group_memberships.create!(end_user: with_mfa)

      expect(emails_for(filter: { group_uid: group.uid })).to eq([ "mfa@shop.test" ])
      expect(emails_for(q: { uid_eq: verified.uid })).to eq([ "verified@shop.test" ])
    end

    it "ignores values it doesn't understand" do
      expect(emails_for(filter: { mfa: "maybe" }).size).to eq(4)
    end
  end

  describe "an end user's app access" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{uid}/access" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "List the apps an end user can sign in to, and how they got access" do
        tags "End users"
        security [ { BearerAuth: [] } ]

        response 200, "apps with the assignments that grant access" do
          schema type: :array, items: Schemas::EndUserAppAccess
        end
      end
    end

    let(:project) { create(:project) }
    let(:admin) { create(:user, :admin, account: project.account) }
    let(:end_user) { create(:end_user, project: project, in_all_end_users_group: false) }

    it "lists direct and group-based access, without the app portal" do
      staff = create(:group, project: project, name: "Staff")
      staff.group_memberships.create!(end_user: end_user)
      crm = create(:app_client, project: project, name: "CRM", assigned_to_everyone: false)
      AppAssignment.create!(project: project, app: crm, principal: end_user)
      AppAssignment.create!(project: project, app: crm, principal: staff)
      wiki = create(:saml_app, project: project, name: "Wiki", assigned_to_everyone: false)
      AppAssignment.create!(project: project, app: wiki, principal: staff)
      create(:app_client, project: project, name: "Hidden", assigned_to_everyone: false)
      project.portal_client!

      assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: end_user.uid)) do
        expect(parsed_body.map { |app| [ app["name"], app["app_type"] ] }).to eq([ %w[CRM app_client], %w[Wiki saml_app] ])
        expect(parsed_body.first["via"].map { |via| via["group_name"] || via["type"] }).to contain_exactly("direct", "Staff")
        expect(parsed_body.last["via"]).to contain_exactly(include("type" => "group", "group_uid" => staff.uid))
      end
    end
  end

  describe "a single end user" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Update an end user's name, attributes or status" do
        tags "End users"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUsers::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::EndUser
        end
      end

      delete "Delete an end user" do
        tags "End users"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"
      end
    end

    let(:end_user) { create(:end_user, project: project) }

    it "disables the end user and signs them out" do
      tokens = tokens_for(end_user, app_client: create(:app_client, project: project))

      assert_api_response :patch, 200, headers: auth_headers_for(admin), body: { status: "disabled" }, path_params: project_path_params(project, uid: end_user.uid)

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end

    it "deletes the end user" do
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: end_user.uid)

      expect(EndUser.exists?(end_user.id)).to be(false)
    end

    it "returns not_found for an end user of another project" do
      other = create(:end_user)

      delete "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/end-users/#{other.uid}", headers: auth_headers_for(admin)

      expect([ response.status, EndUser.exists?(other.id) ]).to eq([ 404, true ])
    end
  end

  it "resets an end user's MFA" do
    end_user = create(:end_user, :with_mfa, project: project)

    delete "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/end-users/#{end_user.uid}/mfa", headers: auth_headers_for(admin)

    expect([ response.status, end_user.reload.mfa_enabled? ]).to eq([ 204, false ])
  end
end
