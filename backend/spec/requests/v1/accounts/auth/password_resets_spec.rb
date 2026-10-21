require "rails_helper"
require "openapi_helper"

RSpec.describe "Password reset", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  describe "requesting a reset" do
    api_path "/v1/accounts/{account_uid}/auth/forgot-password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Email a password reset link" do
        tags "Password reset"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Auth::ForgotPasswordRequest.as_schema } }

        response 202, "accepted, whether or not the email exists"
      end
    end

    it "queues the reset email for an existing user" do
      expect { assert_api_response :post, 202, body: { email: user.email.upcase }, path_params: path_params }
        .to have_enqueued_job(PasswordResetEmailJob).with(hash_including(account_id: account.id, email: user.email))
    end

    it "handles unknown emails exactly like existing ones" do
      expect { assert_api_response :post, 202, body: { email: "nobody@example.com" }, path_params: path_params }
        .to have_enqueued_job(PasswordResetEmailJob).with(hash_including(email: "nobody@example.com"))
    end
  end

  describe "resetting the password" do
    api_path "/v1/accounts/{account_uid}/auth/reset-password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Set a new password with a reset token" do
        tags "Password reset"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Auth::ResetPasswordRequest.as_schema } }

        response 204, "password changed"

        response 401, "invalid or expired token" do
          schema Schemas::Error
        end

        response 422, "password breaks the account's rules" do
          schema Schemas::Error
        end
      end
    end

    let(:token) { OneTimeToken.issue!(subject: user, purpose: :password_reset).last }

    it "changes the password" do
      assert_api_response :post, 204, body: { token: token, password: "a brand new passphrase" }, path_params: path_params

      expect(Passwords::Hasher.new.matches?("a brand new passphrase", user.reload.password_digest)).to be(true)
    end

    it "signs out every existing session" do
      tokens = tokens_for(user)

      assert_api_response :post, 204, body: { token: token, password: "a brand new passphrase" }, path_params: path_params

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end

    it "keeps the token usable when the password is rejected" do
      assert_api_response :post, 422, body: { token: token, password: "short" }, path_params: path_params

      assert_api_response :post, 204, body: { token: token, password: "a brand new passphrase" }, path_params: path_params
    end

    it "refuses a token that was already used" do
      assert_api_response :post, 204, body: { token: token, password: "a brand new passphrase" }, path_params: path_params

      assert_api_response :post, 401, body: { token: token, password: "another new passphrase" }, path_params: path_params
    end

    it "refuses an expired token" do
      token

      travel 61.minutes do
        assert_api_response :post, 401, body: { token: token, password: "a brand new passphrase" }, path_params: path_params
      end
    end

    it "refuses a token from another account" do
      assert_api_response :post, 401, body: { token: token, password: "a brand new passphrase" },
        path_params: { account_uid: create(:account).uid }
    end
  end
end
