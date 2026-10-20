require "rails_helper"
require "openapi_helper"

RSpec.describe "Me", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  describe "the signed-in user" do
    api_path "/v1/accounts/{account_uid}/me" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "The signed-in user and their account" do
        tags "Me"
        security [ { BearerAuth: [] } ]

        response 200, "the signed-in user" do
          schema Schemas::Me
        end

        response 401, "missing, invalid or revoked access token" do
          schema Schemas::Error
        end
      end

      patch "Update your profile" do
        tags "Me"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: NameRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::Me
        end

        response 422, "invalid name" do
          schema Schemas::Error
        end
      end
    end

    it "returns the signed-in user" do
      assert_api_response :get, 200, headers: auth_headers_for(user), path_params: path_params do
        expect([ parsed_body["uid"], parsed_body.dig("account", "uid") ]).to eq([ user.uid, account.uid ])
      end
    end

    it "requires an access token" do
      assert_api_response(:get, 401, path_params: path_params) { expect(error_code).to eq("unauthorized") }
    end

    it "rejects a token issued by another account" do
      other_user = create(:user)

      assert_api_response(:get, 401, headers: auth_headers_for(other_user), path_params: path_params) do
        expect(error_code).to eq("invalid_token")
      end
    end

    it "rejects a token issued before the user's sessions were revoked" do
      headers = auth_headers_for(user)
      travel 1.second do
        user.revoke_all_sessions!

        assert_api_response :get, 401, headers: headers, path_params: path_params
      end
    end

    it "rejects an expired token" do
      headers = auth_headers_for(user)

      travel 16.minutes do
        assert_api_response :get, 401, headers: headers, path_params: path_params
      end
    end

    it "rejects tokens of disabled users" do
      headers = auth_headers_for(user)
      user.update!(status: "disabled")

      assert_api_response :get, 401, headers: headers, path_params: path_params
    end

    it "updates the user's name" do
      assert_api_response :patch, 200, headers: auth_headers_for(user), body: { name: "New Name" }, path_params: path_params do
        expect(parsed_body["name"]).to eq("New Name")
      end
    end

    it "rejects a blank name" do
      assert_api_response :patch, 422, headers: auth_headers_for(user), body: { name: "" }, path_params: path_params
    end
  end

  describe "changing the password" do
    api_path "/v1/accounts/{account_uid}/me/password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      put "Change your password" do
        tags "Me"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: ChangePasswordRequest.as_schema } }

        response 204, "password changed; other sessions signed out"

        response 422, "wrong current password or invalid new password" do
          schema Schemas::Error
        end
      end
    end

    let(:body) { { current_password: "correct horse battery staple", new_password: "a brand new passphrase" } }

    it "changes the password" do
      assert_api_response :put, 204, headers: auth_headers_for(user), body: body, path_params: path_params

      expect(Passwords::Hasher.new.matches?("a brand new passphrase", user.reload.password_digest)).to be(true)
    end

    it "signs out other sessions but keeps the current one" do
      other_session = tokens_for(user)
      current_session = tokens_for(user)

      assert_api_response :put, 204, headers: { "Authorization" => "Bearer #{current_session.access_token}" }, body: body,
        path_params: path_params

      expect([ RefreshToken.find_by_token(other_session.refresh_token).revoked?, RefreshToken.find_by_token(current_session.refresh_token).revoked? ])
        .to eq([ true, false ])
    end

    it "requires the current password" do
      assert_api_response :put, 422, headers: auth_headers_for(user), body: body.merge(current_password: "wrong password!!"),
        path_params: path_params do
        expect(parsed_body.dig("error", "details", 0, "field")).to eq("current_password")
      end
    end
  end
end
