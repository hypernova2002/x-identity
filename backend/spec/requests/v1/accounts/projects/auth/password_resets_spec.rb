require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user password reset", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, project: project) }
  let(:path_params) { project_path_params(project) }

  describe "requesting a code" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/forgot-password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Email a password reset code" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ForgotPasswordRequest.as_schema } }

        response 202, "accepted, whether or not the email exists"
      end
    end

    it "queues the lookup for known and unknown addresses alike" do
      expect { assert_api_response :post, 202, body: { client_id: app_client.uid, email: "nobody@shop.test" }, path_params: path_params }
        .to have_enqueued_job(EndUserLookupEmailJob).with(hash_including(kind: "password_reset", email: "nobody@shop.test"))
    end

    it "emails end users who haven't chosen a language in the language of the request" do
      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs do
        assert_api_response :post, 202, headers: { "Accept-Language" => "fr-FR, ja;q=0.9, en;q=0.8" },
          body: { client_id: app_client.uid, email: end_user.email }, path_params: path_params
      end

      expect(ActionMailer::Base.deliveries.last.subject).to eq("#{project.name} のパスワードのリセット")
    end
  end

  describe "setting the new password" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/confirm-forgot-password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Set a new password with the code or link token from the email" do
        tags "End-user auth"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: EndUserAuth::ConfirmForgotPasswordRequest.as_schema } }

        response 204, "password changed; every session signed out"

        response 400, "wrong or expired code" do
          schema Schemas::Error
        end

        response 422, "password breaks the project's rules" do
          schema Schemas::Error
        end
      end
    end

    let!(:issued) { OneTimeToken.issue_with_code!(subject: end_user, purpose: :password_reset) }

    def confirm(status, fields, &block)
      assert_api_response(:post, status, body: { client_id: app_client.uid, password: "a brand new passphrase", **fields }, path_params: path_params, &block)
    end

    it "changes the password with email and code" do
      confirm(204, email: end_user.email, code: issued.code)

      expect(Passwords::Hasher.new.matches?("a brand new passphrase", end_user.reload.password_digest)).to be(true)
    end

    it "changes the password with the link token" do
      confirm(204, token: issued.token)
    end

    it "signs out every session" do
      tokens = tokens_for(end_user, app_client: app_client)

      confirm(204, email: end_user.email, code: issued.code)

      expect(RefreshToken.find_by_token(tokens.refresh_token)).to be_revoked
    end

    it "keeps the code usable when the password is rejected" do
      confirm(422, email: end_user.email, code: issued.code, password: "short")

      confirm(204, email: end_user.email, code: issued.code)
    end

    it "rejects a wrong code" do
      confirm(400, email: end_user.email, code: "999999")
    end
  end

  it "emails a code to active end users only" do
    ActionMailer::Base.deliveries.clear
    EndUsers::PasswordReset.new(project: project).deliver(email: end_user.email)
    EndUsers::PasswordReset.new(project: project).deliver(email: "nobody@shop.test")

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ end_user.email ] ])
  end
end
