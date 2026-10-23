require "rails_helper"
require "openapi_helper"

RSpec.describe "Users", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:owner) { create(:user, :owner, account: account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:member) { create(:user, account: account) }

  describe "listing" do
    api_path "/v1/accounts/{account_uid}/users" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "List the account's users" do
        tags "Users"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Name or email", sorts: %w[name email role last_sign_in_at created_at], filters: { role_eq: { type: :string }, status_eq: { type: :string } }).each { |list_parameter| parameter(**list_parameter) }

        response 200, "users, paginated with Total, Per-Page and Link headers" do
          schema type: :array, items: Schemas::User
          header "Total", schema: { type: :integer }
          header "Per-Page", schema: { type: :integer }
          header "Link", schema: { type: :string }
        end
      end
    end

    it "lists only users in the account" do
      member
      create(:user)

      assert_api_response :get, 200, headers: auth_headers_for(owner), path_params: { account_uid: account.uid } do
        expect(parsed_body.pluck("uid")).to contain_exactly(owner.uid, member.uid)
      end
    end

    it "puts pagination metadata in headers" do
      member

      assert_api_response :get, 200, headers: auth_headers_for(owner), params: { per_page: 1 }, path_params: { account_uid: account.uid } do
        expect([ response.headers["Total"], response.headers["Per-Page"], parsed_body.size ]).to eq([ "2", "1", 1 ])
      end
    end

    it "caps the page size" do
      assert_api_response :get, 200, headers: auth_headers_for(owner), params: { per_page: 1000 }, path_params: { account_uid: account.uid } do
        expect(response.headers["Per-Page"]).to eq(Paginated::MAX_PER_PAGE.to_s)
      end
    end

    it "does not expose database ids" do
      assert_api_response :get, 200, headers: auth_headers_for(owner), path_params: { account_uid: account.uid } do
        expect(parsed_body.first.keys).not_to include("id", "account_id")
      end
    end
  end

  describe "updating" do
    api_path "/v1/accounts/{account_uid}/users/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Change a user's role or status" do
        tags "Users"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Users::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::User
        end

        response 403, "not allowed to manage this user" do
          schema Schemas::Error
        end

        response 404, "no such user in this account" do
          schema Schemas::Error
        end

        response 409, "would leave the account without an active owner" do
          schema Schemas::Error
        end
      end

      delete "Delete a user" do
        tags "Users"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"

        response 403, "not allowed to manage this user" do
          schema Schemas::Error
        end
      end
    end

    def update_user(actor, target, status, body, account_uid: account.uid)
      assert_api_response :patch, status, headers: auth_headers_for(actor), body: body, path_params: { account_uid: account_uid, uid: target.uid }
    end

    it "lets an admin promote a member to admin" do
      update_user(admin, member, 200, { role: "admin" })

      expect(member.reload).to be_admin
    end

    it "does not let an admin grant the owner role" do
      update_user(admin, member, 403, { role: "owner" })
    end

    it "does not let an admin change an owner" do
      update_user(admin, owner, 403, { role: "member" })
    end

    it "does not let members manage users" do
      update_user(member, admin, 403, { role: "member" })
    end

    it "does not let users change themselves" do
      update_user(owner, owner, 403, { role: "member" })
    end

    it "lets an owner demote another owner" do
      other_owner = create(:user, :owner, account: account)

      update_user(owner, other_owner, 200, { role: "admin" })
    end

    it "signs out a user who is disabled" do
      tokens = tokens_for(member)

      update_user(admin, member, 200, { status: "disabled" })

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end

    it "returns not_found for a user in another account" do
      other_user = create(:user)

      update_user(owner, other_user, 404, { role: "admin" })
    end

    it "deletes a user" do
      assert_api_response :delete, 204, headers: auth_headers_for(owner), path_params: { account_uid: account.uid, uid: member.uid }

      expect(User.exists?(member.id)).to be(false)
    end

    it "records role changes in the audit log" do
      update_user(admin, member, 200, { role: "admin" })

      expect(account.audit_events.last).to have_attributes(action: "user.role_changed", metadata: { "from" => "member", "to" => "admin" })
    end
  end

  describe "searching and sorting" do
    def emails(params)
      get "/v1/accounts/#{account.uid}/users", params: params, headers: auth_headers_for(owner)
      response.parsed_body.pluck("email")
    end

    before do
      create(:user, :admin, account: account, name: "Robin Admin", email: "robin@acme.test")
      create(:user, account: account, name: "Casey Member", email: "casey@acme.test")
    end

    it "searches names and emails, filters by role and sorts" do
      expect(emails(q: { search: "robin" })).to eq([ "robin@acme.test" ])
      expect(emails(q: { search: "casey@" })).to eq([ "casey@acme.test" ])
      expect(emails(q: { role_eq: "member" })).to eq([ "casey@acme.test" ])
      expect(emails(sort: "name")).to eq([ "casey@acme.test", "robin@acme.test", owner.email ])
      expect(emails(sort: "-name")).to eq([ owner.email, "robin@acme.test", "casey@acme.test" ])
    end
  end
end
