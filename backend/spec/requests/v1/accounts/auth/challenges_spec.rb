require "rails_helper"
require "openapi_helper"

RSpec.describe "Sign-in challenges", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:configuration) { account.auth_configuration! }
  let(:path_params) { { account_uid: account.uid } }

  def start_sign_in(user)
    Auth::SignIn.new(context: Auth::SignInContext.new(realm: account.realm)).call(email: user.email, password: "correct horse battery staple").session
  end

  describe "responding to a challenge" do
    api_path "/v1/accounts/{account_uid}/auth/respond-to-challenge" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Answer a sign-in challenge" do
        tags "Sign in"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Auth::ChallengeResponseRequest.as_schema } }

        response 200, "tokens, or the next challenge" do
          schema Schemas::SignInResult
        end

        response 401, "wrong code or invalid session" do
          schema Schemas::Error
        end

        response 422, "invalid new password" do
          schema Schemas::Error
        end

        response 403, "user disabled after too many wrong codes in a row" do
          schema Schemas::Error
        end

        response 429, "locked out after too many failures" do
          schema Schemas::Error
        end
      end
    end

    context "with an otp challenge" do
      let(:user) { create(:user, :with_mfa, account: account) }
      let(:session) { start_sign_in(user) }

      it "returns tokens that record OTP use" do
        assert_api_response :post, 200, body: { challenge: "otp", session: session, code: current_totp_for(user) }, path_params: path_params do
          claims = Auth::AccessTokenVerifier.new(realm: account.realm).verify(parsed_body["access_token"])
          expect(claims["amr"]).to eq(%w[pwd otp])
        end
      end

      it "accepts a recovery code" do
        code = RecoveryCode.regenerate_for!(user).first

        assert_api_response :post, 200, body: { challenge: "otp", session: session, code: code }, path_params: path_params
      end

      it "rejects a wrong code but keeps the session usable" do
        assert_api_response :post, 401, body: { challenge: "otp", session: session, code: "000000" }, path_params: path_params
        assert_api_response :post, 200, body: { challenge: "otp", session: session, code: current_totp_for(user) }, path_params: path_params
      end

      it "refuses to reuse a session once it has succeeded" do
        body = { challenge: "otp", session: session, code: current_totp_for(user) }
        assert_api_response :post, 200, body: body, path_params: path_params

        assert_api_response(:post, 401, body: body, path_params: path_params) { expect(error_code).to eq("invalid_challenge") }
      end

      it "rejects a session from another account" do
        other_account = create(:account)

        assert_api_response :post, 401, body: { challenge: "otp", session: session, code: current_totp_for(user) },
          path_params: { account_uid: other_account.uid }
      end

      it "disables the user after too many wrong codes in a row" do
        configuration.update!(mfa_max_failed_attempts: 3)
        2.times { assert_api_response :post, 401, body: { challenge: "otp", session: session, code: "000000" }, path_params: path_params }

        assert_api_response(:post, 403, body: { challenge: "otp", session: session, code: "000000" }, path_params: path_params) do
          expect([ error_code, user.reload.status ]).to eq([ "user_disabled", "disabled" ])
        end
      end

      it "locks the account's last active owner out temporarily instead of disabling them" do
        owner = create(:user, :owner, :with_mfa, account: account)
        owner_session = start_sign_in(owner)
        configuration.update!(mfa_max_failed_attempts: 3)
        2.times { assert_api_response :post, 401, body: { challenge: "otp", session: owner_session, code: "000000" }, path_params: path_params }

        assert_api_response(:post, 429, body: { challenge: "otp", session: owner_session, code: "000000" }, path_params: path_params) do
          expect([ error_code, owner.reload.status ]).to eq([ "too_many_attempts", "active" ])
        end
      end

      it "starts counting again after a correct code" do
        configuration.update!(mfa_max_failed_attempts: 3)
        2.times { assert_api_response :post, 401, body: { challenge: "otp", session: session, code: "000000" }, path_params: path_params }
        assert_api_response :post, 200, body: { challenge: "otp", session: session, code: current_totp_for(user) }, path_params: path_params

        expect(user.reload.failed_mfa_attempts).to eq(0)
      end
    end

    context "with a new_password challenge" do
      let(:user) { create(:user, account: account, password_changed_at: 100.days.ago) }
      let(:session) { start_sign_in(user) }

      before { configuration.update!(password_max_age_seconds: 90.days.to_i) }

      it "sets the new password and signs in" do
        assert_api_response :post, 200, body: { challenge: "new_password", session: session, new_password: "a brand new passphrase" },
          path_params: path_params do
          expect(Passwords::Hasher.new.matches?("a brand new passphrase", user.reload.password_digest)).to be(true)
        end
      end

      it "rejects reusing the current password" do
        assert_api_response :post, 422, body: { challenge: "new_password", session: session, new_password: "correct horse battery staple" },
          path_params: path_params
      end
    end

    context "with an mfa_setup challenge" do
      let(:user) { create(:user, account: account) }
      let(:session) { start_sign_in(user) }

      before { configuration.update!(mfa_requirement: "required") }

      it "confirms the new authenticator and returns tokens with recovery codes" do
        enrollment = Auth::ChallengeResponse.new(context: Auth::SignInContext.new(realm: account.realm)).start_mfa_setup(session: session)
        code = ROTP::TOTP.new(enrollment.secret).now

        assert_api_response :post, 200, body: { challenge: "mfa_setup", session: session, code: code }, path_params: path_params do
          expect([ parsed_body.key?("access_token"), parsed_body["recovery_codes"].size ]).to eq([ true, RecoveryCode::COUNT ])
        end
      end
    end
  end

  describe "starting MFA setup" do
    api_path "/v1/accounts/{account_uid}/auth/mfa-setup" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Get a TOTP secret while answering an mfa_setup challenge" do
        tags "Sign in"
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Auth::MfaSetupRequest.as_schema } }

        response 200, "secret and QR code" do
          schema Schemas::MfaEnrollment
        end

        response 401, "invalid session" do
          schema Schemas::Error
        end
      end
    end

    it "returns a secret for a user answering mfa_setup" do
      configuration.update!(mfa_requirement: "required")
      session = start_sign_in(create(:user, account: account))

      assert_api_response :post, 200, body: { session: session }, path_params: path_params
    end

    it "refuses sessions issued for other challenges" do
      session = start_sign_in(create(:user, :with_mfa, account: account))

      assert_api_response :post, 401, body: { session: session }, path_params: path_params
    end
  end
end
