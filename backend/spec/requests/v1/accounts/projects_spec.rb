require "rails_helper"
require "openapi_helper"

RSpec.describe "Projects", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:member) { create(:user, account: account) }
  let!(:project) { create(:project, account: account, name: "Production") }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "List projects you can see" do
        tags "Projects"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Name", sorts: %w[name created_at], filters: { created_at_gteq: { type: :string, format: "date-time" }, created_at_lteq: { type: :string, format: "date-time" } }).each { |list_parameter| parameter(**list_parameter) }

        response 200, "projects" do
          schema type: :array, items: Schemas::Project
        end
      end

      post "Create a project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Projects::CreateRequest.as_schema } }

        response 201, "created" do
          schema Schemas::Project
        end

        response 403, "only account owners and admins can create projects" do
          schema Schemas::Error
        end
      end
    end

    it "shows admins every project" do
      assert_api_response :get, 200, headers: auth_headers_for(admin), path_params: { account_uid: account.uid } do
        expect(parsed_body.pluck("uid")).to eq([ project.uid ])
      end
    end

    it "shows members only projects they belong to" do
      other_project = create(:project, account: account)
      create(:project_membership, project: other_project, user: member)

      assert_api_response :get, 200, headers: auth_headers_for(member), path_params: { account_uid: account.uid } do
        expect(parsed_body.pluck("uid")).to eq([ other_project.uid ])
      end
    end

    it "lets admins create projects" do
      assert_api_response :post, 201, headers: auth_headers_for(admin), body: { name: "Staging" }, path_params: { account_uid: account.uid }
    end

    it "does not let members create projects" do
      assert_api_response :post, 403, headers: auth_headers_for(member), body: { name: "Staging" }, path_params: { account_uid: account.uid }
    end
  end

  describe "a single project" do
    api_path "/v1/accounts/{account_uid}/projects/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "Show a project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]

        response 200, "the project" do
          schema Schemas::Project
        end

        response 401, "token issued by another account" do
          schema Schemas::Error
        end

        response 404, "no such project, or you can't see it" do
          schema Schemas::Error
        end
      end

      patch "Rename a project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Projects::UpdateRequest.as_schema } }

        response 200, "renamed" do
          schema Schemas::Project
        end

        response 403, "not a project or account admin" do
          schema Schemas::Error
        end
      end

      delete "Delete a project" do
        tags "Projects"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"

        response 403, "only account owners and admins can delete projects" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { { account_uid: account.uid, uid: project.uid } }

    it "hides projects the user isn't a member of" do
      assert_api_response :get, 404, headers: auth_headers_for(member), path_params: path_params
    end

    it "hides projects of other accounts, even from their admins" do
      other_admin = create(:user, :admin)

      assert_api_response :get, 401, headers: auth_headers_for(other_admin), path_params: path_params
    end

    it "returns not_found when the project belongs to another account" do
      other_project = create(:project)

      assert_api_response :get, 404, headers: auth_headers_for(admin), path_params: { account_uid: account.uid, uid: other_project.uid }
    end

    it "lets project admins rename the project" do
      create(:project_membership, project: project, user: member, role: "admin")

      assert_api_response :patch, 200, headers: auth_headers_for(member), body: { name: "Prod" }, path_params: path_params
    end

    it "does not let project viewers rename the project" do
      create(:project_membership, project: project, user: member, role: "viewer")

      assert_api_response :patch, 403, headers: auth_headers_for(member), body: { name: "Prod" }, path_params: path_params
    end

    it "does not let project admins delete the project" do
      create(:project_membership, project: project, user: member, role: "admin")

      assert_api_response :delete, 403, headers: auth_headers_for(member), path_params: path_params
    end

    it "lets account admins delete the project" do
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params
    end
  end

  describe "searching and sorting" do
    def names(params)
      get "/v1/accounts/#{account.uid}/projects", params: params, headers: auth_headers_for(admin)
      response.parsed_body.pluck("name")
    end

    it "searches by name and sorts either way" do
      create(:project, account: account, name: "Staging")

      expect(names(q: { search: "stag" })).to eq([ "Staging" ])
      expect(names(sort: "-name")).to eq(%w[Staging Production])
    end

    it "still shows members only their projects" do
      create(:project, account: account, name: "Secret")

      get "/v1/accounts/#{account.uid}/projects", params: { q: { search: "Secret" } }, headers: auth_headers_for(member)

      expect(response.parsed_body).to be_empty
    end
  end
end
