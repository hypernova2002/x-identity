require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user email confirmation", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, :unverified, project: project) }
  let(:path_params) { project_path_params(project) }

  describe "confirming" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/confirm-sign-up" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm an end user's email with the code or link token from the email" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ConfirmSignUpRequest.as_schema } }

        response 204, "email confirmed"

        response 400, "wrong or expired code" do
          schema Schemas::Error
        end

        response 422, "neither a token nor email and code were sent" do
          schema Schemas::Error
        end
      end
    end

    let!(:issued) { OneTimeToken.issue_with_code!(subject: end_user, purpose: :email_verification) }

    def confirm(status, fields, &block)
      assert_api_response(:post, status, body: { client_id: app_client.uid, **fields }, path_params: path_params, &block)
    end

    it "confirms with email and code" do
      confirm(204, email: end_user.email, code: issued.code)

      expect(end_user.reload).to be_email_verified
    end

    it "confirms with the token from the email link" do
      confirm(204, token: issued.token)

      expect(end_user.reload).to be_email_verified
    end

    it "rejects a wrong code" do
      confirm(400, email: end_user.email, code: "000000") { expect(error_code).to eq("invalid_code") }
    end

    it "rejects an unknown email exactly like a wrong code" do
      confirm(400, email: "nobody@shop.test", code: issued.code) { expect(error_code).to eq("invalid_code") }
    end

    it "stops accepting the right code after too many wrong guesses" do
      project.auth_configuration!.email_code_max_attempts.times { |n| confirm(400, email: end_user.email, code: format("%06d", n)) }

      confirm(400, email: end_user.email, code: issued.code)
    end

    it "only works once" do
      confirm(204, email: end_user.email, code: issued.code)

      confirm(400, email: end_user.email, code: issued.code)
    end

    it "requires a token or an email and code" do
      confirm(422, email: end_user.email)
    end

    it "rejects a code for an end user of another project" do
      other = create(:end_user, :unverified)
      other_code = OneTimeToken.issue_with_code!(subject: other, purpose: :email_verification).code

      confirm(400, email: other.email, code: other_code)
    end
  end

  describe "resending" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/resend-confirmation" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Send a new confirmation code" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ResendConfirmationRequest.as_schema } }

        response 202, "accepted, whether or not the email exists"
      end
    end

    it "queues the email for known and unknown addresses alike" do
      expect { assert_api_response :post, 202, body: { client_id: app_client.uid, email: "nobody@shop.test" }, path_params: path_params }
        .to have_enqueued_job(EndUserLookupEmailJob).with(hash_including(kind: "confirmation", email: "nobody@shop.test"))
    end
  end
end
