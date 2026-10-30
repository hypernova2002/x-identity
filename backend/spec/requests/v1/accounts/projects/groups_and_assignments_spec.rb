require "rails_helper"
require "openapi_helper"

RSpec.describe "Groups and app assignments", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }

  describe "groups" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/groups" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the project's groups" do
        tags "Groups"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Name", sorts: %w[name member_count created_at], filters: { default_for_new_users_eq: { type: :string, enum: %w[true false] } }).each { |list_parameter| parameter(**list_parameter) }

        response 200, "groups, with member counts" do
          schema type: :array, items: Schemas::Group
        end
      end

      post "Create a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Groups::CreateRequest.as_schema } }

        response 201, "created" do
          schema Schemas::Group
        end

        response 403, "viewers can't manage groups" do
          schema Schemas::Error
        end

        response 422, "the name is missing or already used" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/groups/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "Get a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]

        response 200, "the group" do
          schema Schemas::Group
        end

        response 404, "no such group in the project" do
          schema Schemas::Error
        end
      end

      patch "Change a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Groups::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::Group
        end

        response 403, "viewers can't manage groups" do
          schema Schemas::Error
        end

        response 422, "the name is invalid or already used" do
          schema Schemas::Error
        end
      end

      delete "Delete a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"

        response 403, "viewers can't manage groups" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/groups/{group_uid}/members" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :group_uid, in: :path, required: true, schema: { type: :string }

      get "List a group's members" do
        tags "Groups"
        security [ { BearerAuth: [] } ]

        response 200, "end users in the group" do
          schema type: :array, items: Schemas::EndUser
        end
      end

      post "Add an end user to a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Groups::AddMemberRequest.as_schema } }

        response 204, "added"

        response 409, "already a member" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/groups/{group_uid}/members/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :group_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Remove an end user from a group" do
        tags "Groups"
        security [ { BearerAuth: [] } ]

        response 204, "removed"

        response 404, "no such group or end user in the project" do
          schema Schemas::Error
        end
      end
    end

    let(:group_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/groups/{uid}" }
    let(:member_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/groups/{group_uid}/members/{uid}" }

    it "shows, changes and deletes a group" do
      group = create(:group, project: project, name: "Support")
      path_params = project_path_params(project, uid: group.uid)

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params, api_path: group_path) do
        expect(parsed_body).to include("uid" => group.uid, "name" => "Support")
      end
      assert_api_response(:patch, 200, headers: auth_headers_for(admin), body: { name: "Help desk" }, path_params: path_params, api_path: group_path) do
        expect(parsed_body).to include("name" => "Help desk")
      end
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params, api_path: group_path

      expect(Group.exists?(group.id)).to be(false)
    end

    it "doesn't let viewers change or delete groups" do
      path_params = project_path_params(project, uid: create(:group, project: project).uid)

      assert_api_response :patch, 403, headers: auth_headers_for(viewer), body: { name: "Help desk" }, path_params: path_params, api_path: group_path
      assert_api_response :delete, 403, headers: auth_headers_for(viewer), path_params: path_params, api_path: group_path
    end

    it "refuses a name another group has" do
      create(:group, project: project, name: "Support")
      path_params = project_path_params(project, uid: create(:group, project: project).uid)

      assert_api_response :patch, 422, headers: auth_headers_for(admin), body: { name: "Support" }, path_params: path_params, api_path: group_path
    end

    it "doesn't show groups of other projects" do
      assert_api_response :get, 404, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: create(:group).uid), api_path: group_path
    end

    it "removes members" do
      group = create(:group, project: project)
      end_user = create(:end_user, project: project)
      group.end_users << end_user

      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: project_path_params(project, group_uid: group.uid, uid: end_user.uid),
        api_path: member_path
      expect(group.end_users.reload).to be_empty

      assert_api_response :delete, 404, headers: auth_headers_for(admin), path_params: project_path_params(project, group_uid: group.uid, uid: create(:end_user).uid),
        api_path: member_path
    end

    it "creates groups, with unique names" do
      body = { name: "Support", description: "Help desk staff" }

      assert_api_response(:post, 201, headers: auth_headers_for(admin), body: body, path_params: project_path_params(project)) do
        expect(parsed_body).to include("name" => "Support", "member_count" => 0, "default_for_new_users" => false)
      end
      assert_api_response(:post, 422, headers: auth_headers_for(admin), body: body, path_params: project_path_params(project))
    end

    it "lists groups with their member counts" do
      group = create(:group, project: project, name: "Staff")
      2.times { group.group_memberships.create!(end_user: create(:end_user, project: project, in_all_end_users_group: false)) }

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: project_path_params(project)) do
        expect(parsed_body.find { |row| row["name"] == "Staff" }["member_count"]).to eq(2)
      end
    end

    it "sorts by member count, a value computed in the query" do
      big = create(:group, project: project, name: "Big")
      create(:group, project: project, name: "Empty")
      2.times { big.group_memberships.create!(end_user: create(:end_user, project: project, in_all_end_users_group: false)) }

      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/groups", params: { sort: "-member_count" }, headers: auth_headers_for(viewer)

      expect(response.parsed_body.first["name"]).to eq("Big")
    end

    it "searches by name and filters groups new users join" do
      create(:group, project: project, name: "Customers", default_for_new_users: true)
      create(:group, project: project, name: "Staff")

      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/groups", params: { q: { default_for_new_users_eq: "true", search: "cust" } }, headers: auth_headers_for(viewer)

      expect(response.parsed_body.pluck("name")).to eq([ "Customers" ])
    end

    it "is managed by developers and admins, not viewers" do
      assert_api_response(:post, 403, headers: auth_headers_for(viewer), body: { name: "Support" }, path_params: project_path_params(project))
    end

    it "adds and lists members" do
      group = create(:group, project: project)
      end_user = create(:end_user, project: project)

      assert_api_response(:post, 204, headers: auth_headers_for(admin), body: { end_user_uid: end_user.uid }, path_params: project_path_params(project, group_uid: group.uid))
      assert_api_response(:post, 409, headers: auth_headers_for(admin), body: { end_user_uid: end_user.uid }, path_params: project_path_params(project, group_uid: group.uid))
      assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: project_path_params(project, group_uid: group.uid)) do
        expect(parsed_body.sole).to include("uid" => end_user.uid, "groups" => include(include("name" => group.name)))
      end
    end

    it "adds new end users to groups marked for new users" do
      create(:group, project: project, name: "Customers", default_for_new_users: true)

      end_user = project.end_users.create!(email: "new@shop.test", email_verified_at: Time.current)

      expect(end_user.groups.pluck(:name)).to include("Customers")
    end
  end

  describe "assignments" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{app_client_uid}/assignments" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :app_client_uid, in: :path, required: true, schema: { type: :string }

      get "List who can use an app client" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 200, "assignments" do
          schema type: :array, items: Schemas::AppAssignment
        end
      end

      post "Give an end user or group access to an app client" do
        tags "App clients"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: AppAssignments::CreateRequest.as_schema } }

        response 201, "assigned" do
          schema Schemas::AppAssignment
        end

        response 404, "no such end user or group in the project" do
          schema Schemas::Error
        end

        response 409, "already assigned" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/app-clients/{app_client_uid}/assignments/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :app_client_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Take away an end user's or group's access to an app client" do
        tags "App clients"
        security [ { BearerAuth: [] } ]

        response 204, "removed"

        response 404, "no such assignment" do
          schema Schemas::Error
        end
      end
    end

    let(:app_client) { create(:app_client, project: project, assigned_to_everyone: false) }
    let!(:end_user) { create(:end_user, project: project, email: "casey@shop.test", in_all_end_users_group: false) }

    def sign_in(status)
      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/sign-in",
        params: { client_id: app_client.uid, email: "casey@shop.test", password: "correct horse battery staple" }, as: :json
      expect(response).to have_http_status(status)
    end

    it "refuses sign-in to apps the user isn't assigned to, and records it" do
      sign_in(:forbidden)

      expect(error_code).to eq("app_access_denied")
      expect(AuditEvent.last).to have_attributes(action: "end_user.app_access_denied", actor_uid: end_user.uid)
    end

    it "allows sign-in once the user's group is assigned" do
      group = create(:group, project: project, name: "Staff")
      group.group_memberships.create!(end_user: end_user)

      assert_api_response(:post, 201, headers: auth_headers_for(admin), body: { principal_type: "group", principal_uid: group.uid },
        path_params: project_path_params(project, app_client_uid: app_client.uid)) do
        expect(parsed_body).to include("principal_type" => "group", "principal_label" => "Staff")
      end

      sign_in(:ok)
    end

    it "refuses refreshes after the assignment is removed" do
      assignment = AppAssignment.create!(project: project, app: app_client, principal: end_user)
      tokens = tokens_for(end_user, app_client: app_client)
      assignment.destroy!

      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/refresh",
        params: { client_id: app_client.uid, refresh_token: tokens.refresh_token }, as: :json

      expect(error_code).to eq("app_access_denied")
    end

    it "removes an assignment" do
      assignment = AppAssignment.create!(project: project, app: app_client, principal: end_user)
      path_params = project_path_params(project, app_client_uid: app_client.uid, uid: assignment.uid)

      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params
      assert_api_response :delete, 404, headers: auth_headers_for(admin), path_params: path_params
    end

    it "lets everyone use the app portal" do
      expect(Apps::Access.allowed?(project.portal_client!, end_user)).to be(true)
    end

    it "doesn't let principals from another project be assigned" do
      other = create(:end_user)

      assert_api_response(:post, 404, headers: auth_headers_for(admin), body: { principal_type: "end_user", principal_uid: other.uid },
        path_params: project_path_params(project, app_client_uid: app_client.uid))
    end
  end

  describe "the app portal" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/portal" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "The app portal's sign-in settings" do
        tags "App portal"

        response 200, "the portal's OpenID Connect client, for its page to sign in with" do
          schema type: :object, required: %w[issuer client_id redirect_uri post_logout_redirect_uri passkeys_available], properties: {
            issuer: { type: :string },
            client_id: { type: :string },
            redirect_uri: { type: :string },
            post_logout_redirect_uri: { type: :string },
            passkeys_available: { type: :boolean, description: "End users can sign in to the portal with a passkey." }
          }
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/portal/apps" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the apps the signed-in end user can open" do
        tags "App portal"
        security [ { BearerAuth: [] } ]

        response 200, "assigned apps with a launch URL" do
          schema type: :array, items: { type: :object, required: %w[uid kind name launch_url] }
        end
      end
    end

    it "lists assigned SAML apps, and assigned app clients with a launch URL" do
      end_user = create(:end_user, project: project)
      saml_app = create(:saml_app, project: project, name: "Wiki")
      create(:saml_app, project: project, name: "Hidden", assigned_to_everyone: false)
      create(:app_client, project: project, name: "CRM", launch_url: "https://crm.example.com")
      create(:app_client, project: project, name: "Backend job")
      headers = { "Authorization" => "Bearer #{tokens_for(end_user, app_client: project.portal_client!).access_token}" }

      assert_api_response(:get, 200, headers: headers, path_params: project_path_params(project), api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/portal/apps") do
        expect(parsed_body.map { |app| [ app["name"], app["kind"] ] }).to eq([ [ "CRM", "oidc" ], [ "Wiki", "saml" ] ])
        expect(parsed_body.last["launch_url"]).to eq(saml_app.launch_url)
      end
    end

    it "tells the portal page its client id" do
      assert_api_response(:get, 200, path_params: project_path_params(project), api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/portal") do
        expect(parsed_body).to include("client_id" => project.portal_client!.uid, "redirect_uri" => end_with("/apps"))
      end
    end

    it "keeps the portal client out of the app clients list" do
      project.portal_client!

      get "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/app-clients", headers: auth_headers_for(admin)

      expect(response.parsed_body).to be_empty
    end
  end
end
