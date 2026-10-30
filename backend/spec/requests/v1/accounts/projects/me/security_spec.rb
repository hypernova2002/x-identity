require "rails_helper"
require "openapi_helper"
require "webauthn/fake_client"

RSpec.describe "End-user security", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project, allowed_origins: [ "https://app.acme.com" ]) }
  let(:end_user) { create(:end_user, project: project, email: "casey@acme.com") }
  let(:tokens) { tokens_for(end_user, app_client: app_client) }
  let(:headers) { { "Authorization" => "Bearer #{tokens.access_token}" } }
  let(:path_params) { project_path_params(project) }

  describe "password" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/password" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      put "Change your password" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::ChangePasswordRequest.as_schema } }

        response 204, "password changed; other sessions signed out"

        response 422, "wrong current password or invalid new password" do
          schema Schemas::Error
        end
      end
    end

    let(:body) { { current_password: "correct horse battery staple", new_password: "a brand new passphrase" } }

    it "changes the password, keeping the current session" do
      other_session = tokens_for(end_user, app_client: app_client)

      assert_api_response :put, 204, headers: headers, body: body, path_params: path_params

      expect(Passwords::Hasher.new.matches?("a brand new passphrase", end_user.reload.password_digest)).to be(true)
      expect([ RefreshToken.find_by_token(other_session.refresh_token).revoked?, RefreshToken.find_by_token(tokens.refresh_token).revoked? ])
        .to eq([ true, false ])
    end

    it "requires the current password" do
      assert_api_response :put, 422, headers: headers, body: body.merge(current_password: "wrong password!!"), path_params: path_params
    end
  end

  describe "email" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/email" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Request an email change" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::EmailChangeRequest.as_schema } }

        response 202, "accepted; a code is sent to the new address if it is available"

        response 422, "wrong password or invalid email" do
          schema Schemas::Error
        end
      end
    end

    let(:body) { { new_email: "new@acme.com", current_password: "correct horse battery staple" } }

    it "keeps the current email until the change is confirmed" do
      assert_api_response :post, 202, headers: headers, body: body, path_params: path_params

      expect(end_user.reload.email).to eq("casey@acme.com")
    end

    it "responds the same way when another end user has the email" do
      create(:end_user, project: project, email: "new@acme.com")

      assert_api_response :post, 202, headers: headers, body: body, path_params: path_params
    end

    it "requires the current password" do
      assert_api_response :post, 422, headers: headers, body: body.merge(current_password: "wrong password!!"), path_params: path_params
    end
  end

  describe "authenticator app" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/otp" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Start setting up an authenticator app or hardware token" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        request_body required: false, content: { "application/json" => { schema: Me::StartOtpRequest.as_schema } }

        response 201, "secret and QR code" do
          schema Schemas::MfaEnrollment
        end

        response 409, "MFA is already turned on" do
          schema Schemas::Error
        end

        response 422, "unknown fields, such as choosing a method" do
          schema Schemas::Error
        end
      end

      delete "Turn off MFA" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::DisableOtpRequest.as_schema } }

        response 204, "MFA turned off"

        response 403, "the project requires MFA" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/otp/confirm" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm the authenticator app with a code" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::ConfirmOtpRequest.as_schema } }

        response 200, "MFA turned on" do
          schema Schemas::RecoveryCodes
        end

        response 401, "wrong code" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/recovery-codes" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Replace your recovery codes" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::RegenerateRecoveryCodesRequest.as_schema } }

        response 201, "new recovery codes; the old ones stop working" do
          schema Schemas::RecoveryCodes
        end

        response 401, "wrong code" do
          schema Schemas::Error
        end

        response 404, "MFA isn't turned on" do
          schema Schemas::Error
        end
      end
    end

    let(:otp_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/me/otp" }

    it "sets up an authenticator app" do
      secret = nil
      assert_api_response(:post, 201, headers: headers, path_params: path_params, api_path: otp_path) { secret = parsed_body["secret"] }

      assert_api_response :post, 401, headers: headers, body: { code: "000000" }, path_params: path_params, api_path: "#{otp_path}/confirm"
      assert_api_response :post, 200, headers: headers, body: { code: ROTP::TOTP.new(secret).now }, path_params: path_params, api_path: "#{otp_path}/confirm"
      expect(end_user.reload).to be_mfa_enabled
      assert_api_response :post, 409, headers: headers, path_params: path_params, api_path: otp_path
    end

    it "doesn't let end users choose a different method" do
      assert_api_response :post, 422, headers: headers, body: { otp_type: "hotp" }, path_params: path_params, api_path: otp_path
    end

    context "with MFA on" do
      let(:end_user) { create(:end_user, :with_mfa, project: project) }

      it "replaces recovery codes with a current code" do
        assert_api_response :post, 401, headers: headers, body: { code: "000000" }, path_params: path_params, api_path: "#{otp_path.delete_suffix('/otp')}/recovery-codes"
        assert_api_response(:post, 201, headers: headers, body: { code: current_totp_for(end_user) }, path_params: path_params,
          api_path: "#{otp_path.delete_suffix('/otp')}/recovery-codes") do
          expect(parsed_body["recovery_codes"].size).to be > 1
        end
      end

      it "turns MFA off, unless the project requires it" do
        body = { current_password: "correct horse battery staple", code: current_totp_for(end_user) }

        project.auth_configuration!.update!(mfa_requirement: "required")
        assert_api_response :delete, 403, headers: headers, body: body, path_params: path_params, api_path: otp_path
        project.auth_configuration!.update!(mfa_requirement: "optional")
        assert_api_response :delete, 204, headers: headers, body: body, path_params: path_params, api_path: otp_path

        expect(end_user.reload).not_to be_mfa_enabled
      end
    end

    it "can't replace recovery codes without MFA" do
      assert_api_response :post, 404, headers: headers, body: { code: "123456" }, path_params: path_params,
        api_path: "/v1/accounts/{account_uid}/projects/{project_uid}/me/recovery-codes"
    end
  end

  describe "passkeys" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/passkeys/options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Start adding a passkey" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 200, "options for navigator.credentials.create, and the registration to send back" do
          schema Schemas::PasskeyRegistrationOptions
        end

        response 403, "the last sign-in was more than 15 minutes ago" do
          schema Schemas::Error
        end

        response 409, "passkeys aren't turned on, or the request doesn't come from the custom domain or the app's allowed origins" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/passkeys" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List your passkeys" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 200, "passkeys, oldest first" do
          schema type: :array, items: Schemas::Passkey
        end
      end

      post "Save the passkey the browser created" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Passkeys::FinishRegistrationRequest.as_schema } }

        response 201, "saved" do
          schema Schemas::Passkey
        end

        response 400, "the passkey couldn't be verified, e.g. the user didn't unlock it, or the registration was used or expired" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/passkeys/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Rename a passkey" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Passkeys::RenameRequest.as_schema } }

        response 200, "renamed" do
          schema Schemas::Passkey
        end
      end

      delete "Remove a passkey" do
        tags "End-user profile"
        security [ { BearerAuth: [] } ]

        response 204, "removed"
      end
    end

    let(:passkeys_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/me/passkeys" }

    before do
      project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
      project.auth_configuration!.update!(passkeys: "optional")
    end

    it "adds, lists, renames and removes passkeys from the app's allowed origin" do
      options = nil
      assert_api_response(:post, 200, headers: headers, path_params: path_params, api_path: "#{passkeys_path}/options") do
        options = parsed_body
        expect(options.dig("public_key", "rp", "id")).to eq("login.acme.com")
      end
      credential = WebAuthn::FakeClient.new("https://app.acme.com", encoding: :base64url)
        .create(challenge: options.dig("public_key", "challenge"), rp_id: "login.acme.com", user_verified: true)
      body = { registration_id: options["registration_id"], credential: credential }

      uid = nil
      assert_api_response(:post, 201, headers: headers, body: body, path_params: path_params, api_path: passkeys_path) { uid = parsed_body["uid"] }
      assert_api_response :post, 400, headers: headers, body: body, path_params: path_params, api_path: passkeys_path
      assert_api_response(:get, 200, headers: headers, path_params: path_params, api_path: passkeys_path) do
        expect(parsed_body.pluck("uid")).to eq([ uid ])
      end
      assert_api_response(:patch, 200, headers: headers, body: { name: "Work laptop" }, path_params: path_params.merge(uid: uid), api_path: "#{passkeys_path}/{uid}") do
        expect(parsed_body["name"]).to eq("Work laptop")
      end
      assert_api_response :delete, 204, headers: headers, path_params: path_params.merge(uid: uid), api_path: "#{passkeys_path}/{uid}"

      expect(end_user.webauthn_credentials).to be_empty
    end

    it "needs a recent sign-in to add a passkey" do
      stale = Auth::TokenIssuer.new(realm: end_user.realm, app_client: app_client).issue(user: end_user, authenticated_at: 16.minutes.ago, amr: [ "pwd" ])

      assert_api_response :post, 403, headers: { "Authorization" => "Bearer #{stale.access_token}" }, path_params: path_params, api_path: "#{passkeys_path}/options"
    end
  end
end
