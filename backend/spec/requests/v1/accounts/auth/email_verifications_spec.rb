require "rails_helper"
require "openapi_helper"

RSpec.describe "Email verification", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, :unverified, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  describe "confirming" do
    api_path "/v1/accounts/{account_uid}/auth/confirm-email" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm an email address" do
        tags "Email verification"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: TokenRequest.as_schema } }

        response 204, "email verified"

        response 401, "invalid or expired token" do
          schema Schemas::Error
        end
      end
    end

    it "marks the email as verified" do
      token = OneTimeToken.issue!(subject: user, purpose: :email_verification).last

      assert_api_response :post, 204, body: { token: token }, path_params: path_params

      expect(user.reload).to be_email_verified
    end

    it "refuses an unknown token" do
      assert_api_response :post, 401, body: { token: "nope" }, path_params: path_params
    end
  end

  describe "resending" do
    api_path "/v1/accounts/{account_uid}/auth/resend-confirmation" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Resend the verification email" do
        tags "Email verification"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EmailRequest.as_schema } }

        response 202, "accepted, whether or not the email exists"
      end
    end

    it "queues the verification email" do
      expect { assert_api_response :post, 202, body: { email: user.email }, path_params: path_params }
        .to have_enqueued_job(VerificationEmailJob).with(account_id: account.id, email: user.email)
    end

    it "handles unknown emails exactly like existing ones" do
      expect { assert_api_response :post, 202, body: { email: "nobody@example.com" }, path_params: path_params }
        .to have_enqueued_job(VerificationEmailJob).with(account_id: account.id, email: "nobody@example.com")
    end
  end
end
