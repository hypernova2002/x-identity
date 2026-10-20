require "rails_helper"
require "openapi_helper"

RSpec.describe "Email change", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, email: "old@acme.test") }
  let(:path_params) { { account_uid: account.uid } }

  describe "requesting a change" do
    api_path "/v1/accounts/{account_uid}/me/email" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Request an email change" do
        tags "Me"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EmailChangeRequest.as_schema } }

        response 202, "accepted; a confirmation is sent to the new address if it is available"

        response 401, "wrong OTP code" do
          schema Schemas::Error
        end

        response 422, "wrong password or invalid email" do
          schema Schemas::Error
        end
      end
    end

    let(:body) { { new_email: "new@acme.test", current_password: "correct horse battery staple" } }

    it "queues the confirmation email" do
      expect { assert_api_response :post, 202, headers: auth_headers_for(user), body: body, path_params: path_params }
        .to have_enqueued_job(EmailChangeEmailJob).with(hash_including(user_id: user.id, new_email: "new@acme.test"))
    end

    it "keeps the current email until the change is confirmed" do
      assert_api_response :post, 202, headers: auth_headers_for(user), body: body, path_params: path_params

      expect(user.reload.email).to eq("old@acme.test")
    end

    it "responds the same way when the email is used by another user in the account" do
      create(:user, account: account, email: "new@acme.test")

      expect { assert_api_response :post, 202, headers: auth_headers_for(user), body: body, path_params: path_params }
        .to have_enqueued_job(EmailChangeEmailJob)
    end

    it "requires an OTP code when MFA is on" do
      user = create(:user, :with_mfa, account: account)

      assert_api_response :post, 401, headers: auth_headers_for(user), body: body, path_params: path_params
    end

    it "requires the current password" do
      assert_api_response :post, 422, headers: auth_headers_for(user), body: body.merge(current_password: "wrong password!!"),
        path_params: path_params
    end
  end

  describe "confirming a change" do
    api_path "/v1/accounts/{account_uid}/auth/confirm-email-change" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm a new email address" do
        tags "Me"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: TokenRequest.as_schema } }

        response 204, "email changed; all sessions signed out"

        response 401, "invalid or expired token" do
          schema Schemas::Error
        end

        response 409, "email taken since the change was requested" do
          schema Schemas::Error
        end
      end
    end

    let(:token) { OneTimeToken.issue!(subject: user, purpose: :email_change, data: { "new_email" => "new@acme.test" }).last }

    it "changes the email" do
      assert_api_response :post, 204, body: { token: token }, path_params: path_params

      expect(user.reload.email).to eq("new@acme.test")
    end

    it "signs out every session" do
      tokens = tokens_for(user)

      assert_api_response :post, 204, body: { token: token }, path_params: path_params

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end

    it "keeps the user's uid" do
      expect { assert_api_response :post, 204, body: { token: token }, path_params: path_params }.not_to(change { user.reload.uid })
    end

    it "refuses when the email was taken in the meantime" do
      token
      create(:user, account: account, email: "new@acme.test")

      assert_api_response :post, 409, body: { token: token }, path_params: path_params
    end
  end
end
