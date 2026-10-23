require "rails_helper"
require "openapi_helper"

RSpec.describe "Invitations", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  describe "inviting" do
    api_path "/v1/accounts/{account_uid}/invitations" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "List pending invitations" do
        tags "Invitations"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Email", sorts: %w[email role expires_at created_at], filters: { role_eq: { type: :string } }).each { |list_parameter| parameter(**list_parameter) }

        response 200, "pending invitations" do
          schema type: :array, items: Schemas::Invitation
        end
      end

      post "Invite someone to the account" do
        tags "Invitations"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Invitations::CreateRequest.as_schema } }

        response 201, "invitation sent" do
          schema Schemas::Invitation
        end

        response 403, "not allowed to invite with this role" do
          schema Schemas::Error
        end

        response 409, "a user with this email already exists" do
          schema Schemas::Error
        end
      end
    end

    it "sends an invitation email" do
      expect { assert_api_response :post, 201, headers: auth_headers_for(admin), body: { email: "new@acme.test", role: "member" }, path_params: path_params }
        .to have_enqueued_mail(InvitationMailer, :invitation)
    end

    it "replaces an earlier pending invitation for the same email" do
      2.times { assert_api_response :post, 201, headers: auth_headers_for(admin), body: { email: "new@acme.test", role: "member" }, path_params: path_params }

      expect(account.invitations.pending.count).to eq(1)
    end

    it "refuses to invite an existing user" do
      create(:user, account: account, email: "taken@acme.test")

      assert_api_response :post, 409, headers: auth_headers_for(admin), body: { email: "taken@acme.test", role: "member" }, path_params: path_params
    end

    it "lets an existing user of another account be invited" do
      create(:user, email: "elsewhere@acme.test")

      assert_api_response :post, 201, headers: auth_headers_for(admin), body: { email: "elsewhere@acme.test", role: "member" }, path_params: path_params
    end

    it "does not let admins invite owners" do
      assert_api_response :post, 403, headers: auth_headers_for(admin), body: { email: "new@acme.test", role: "owner" }, path_params: path_params
    end

    it "lists pending invitations" do
      Invitation.issue!(account: account, invited_by: admin, email: "new@acme.test", role: "member")

      assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: path_params) { expect(parsed_body.size).to eq(1) }
    end
  end

  describe "accepting" do
    api_path "/v1/accounts/{account_uid}/auth/accept-invitation" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Accept an invitation and create your user" do
        tags "Invitations"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Auth::AcceptInvitationRequest.as_schema } }

        response 201, "user created" do
          schema Schemas::User
        end

        response 401, "invalid, expired or revoked invitation" do
          schema Schemas::Error
        end

        response 422, "invalid name or password" do
          schema Schemas::Error
        end
      end
    end

    let(:invitation_and_token) { Invitation.issue!(account: account, invited_by: admin, email: "new@acme.test", role: "admin") }
    let(:token) { invitation_and_token.last }
    let(:body) { { token: token, name: "New Person", password: "correct horse battery staple" } }

    it "creates a verified user with the invited role" do
      assert_api_response :post, 201, body: body, path_params: path_params do
        expect(parsed_body).to include("email" => "new@acme.test", "role" => "admin", "email_verified" => true)
      end
    end

    it "can only be used once" do
      assert_api_response :post, 201, body: body, path_params: path_params

      assert_api_response :post, 401, body: body, path_params: path_params
    end

    it "refuses a revoked invitation" do
      invitation_and_token.first.revoke!

      assert_api_response :post, 401, body: body, path_params: path_params
    end

    it "refuses an invitation from another account" do
      assert_api_response :post, 401, body: body, path_params: { account_uid: create(:account).uid }
    end
  end

  describe "searching and sorting invitations" do
    def emails(params)
      get "/v1/accounts/#{account.uid}/invitations", params: params, headers: auth_headers_for(admin)
      response.parsed_body.pluck("email")
    end

    before do
      Invitation.issue!(account: account, invited_by: admin, email: "zoe@acme.test", role: "member")
      Invitation.issue!(account: account, invited_by: admin, email: "ari@acme.test", role: "admin")
    end

    it "searches by email, filters by role and sorts" do
      expect(emails(q: { search: "zoe" })).to eq([ "zoe@acme.test" ])
      expect(emails(q: { role_eq: "admin" })).to eq([ "ari@acme.test" ])
      expect(emails(sort: "email")).to eq(%w[ari@acme.test zoe@acme.test])
    end
  end
end
