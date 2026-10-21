require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user identities", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:provider) { create(:identity_provider, project: project) }
  let(:end_user) { create(:end_user, project: project) }
  let!(:identity) { create(:end_user_identity, end_user: end_user, identity_provider: provider, subject: "google-123") }

  describe "for admins" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{uid}/identities" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "List an end user's linked identity providers" do
        tags "End users"
        security [ { BearerAuth: [] } ]

        response 200, "linked identities" do
          schema type: :array, items: Schemas::EndUserIdentity
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{uid}/identities/{identity_uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }
      parameter name: :identity_uid, in: :path, required: true, schema: { type: :string }

      delete "Unlink an identity provider from an end user" do
        tags "End users"
        security [ { BearerAuth: [] } ]

        response 204, "unlinked"

        response 403, "viewers can't change end users" do
          schema Schemas::Error
        end

        response 409, "it's the user's only way to sign in" do
          schema Schemas::Error
        end
      end
    end

    let(:admin) { create(:user, :admin, account: project.account) }
    let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }

    it "lists the provider each identity belongs to" do
      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: project_path_params(project, uid: end_user.uid)) do
        expect(parsed_body.sole).to include("uid" => identity.uid, "identity_provider_uid" => provider.uid, "identity_provider_kind" => "google", "subject" => "google-123")
      end
    end

    it "unlinks an identity from a user who has a password" do
      assert_api_response(:delete, 204, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: end_user.uid, identity_uid: identity.uid))

      expect(end_user.identities).to be_empty
      expect(AuditEvent.last).to have_attributes(action: "end_user.identity_unlinked", actor_uid: admin.uid)
    end

    it "keeps the last way to sign in" do
      end_user.update!(password_digest: nil)

      assert_api_response(:delete, 409, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: end_user.uid, identity_uid: identity.uid)) do
        expect(error_code).to eq("last_sign_in_method")
      end
    end

    it "is not for viewers" do
      assert_api_response(:delete, 403, headers: auth_headers_for(viewer), path_params: project_path_params(project, uid: end_user.uid, identity_uid: identity.uid))
    end
  end

  describe "for the end user" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/identities" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List my linked identity providers" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 200, "linked identities" do
          schema type: :array, items: Schemas::EndUserIdentity
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/identities/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Unlink one of my identity providers" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 204, "unlinked"

        response 404, "not one of my identities" do
          schema Schemas::Error
        end

        response 409, "it's my only way to sign in" do
          schema Schemas::Error
        end
      end
    end

    let(:headers) { { "Authorization" => "Bearer #{tokens_for(end_user, app_client: create(:app_client, project: project)).access_token}" } }

    it "lists my identities" do
      assert_api_response(:get, 200, headers: headers, path_params: project_path_params(project)) do
        expect(parsed_body.map { |row| row["uid"] }).to eq([ identity.uid ])
      end
    end

    it "unlinks one when I have another way to sign in" do
      other = create(:end_user_identity, end_user: end_user, identity_provider: create(:identity_provider, :oidc, project: project))
      end_user.update!(password_digest: nil)

      assert_api_response(:delete, 204, headers: headers, path_params: project_path_params(project, uid: identity.uid))

      expect(end_user.identities).to eq([ other ])
    end

    it "keeps my last way to sign in" do
      end_user.update!(password_digest: nil)

      assert_api_response(:delete, 409, headers: headers, path_params: project_path_params(project, uid: identity.uid))
    end

    it "can't touch someone else's identity" do
      someone_else = create(:end_user_identity, end_user: create(:end_user, project: project), identity_provider: provider)

      assert_api_response(:delete, 404, headers: headers, path_params: project_path_params(project, uid: someone_else.uid))
    end
  end
end
