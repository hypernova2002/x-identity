require "rails_helper"
require "openapi_helper"

RSpec.describe "OTP enrolment", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:path_params) { { account_uid: account.uid } }
  let(:headers) { auth_headers_for(user) }

  describe "starting enrolment" do
    api_path "/v1/accounts/{account_uid}/me/otp" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Start setting up an authenticator app or hardware token" do
        tags "Me"
        security [ { BearerAuth: [] } ]

        response 201, "secret and QR code" do
          schema Schemas::MfaEnrollment
        end

        response 422, "unknown fields, such as choosing a method" do
          schema Schemas::Error
        end

        response 409, "MFA is already turned on" do
          schema Schemas::Error
        end
      end

      delete "Turn off MFA" do
        tags "Me"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: Me::DisableOtpRequest.as_schema } }

        response 204, "MFA turned off"

        response 403, "the account requires MFA" do
          schema Schemas::Error
        end
      end
    end

    it "returns a new secret" do
      assert_api_response(:post, 201, headers: headers, path_params: path_params) { expect(parsed_body["secret"]).to be_present }
    end

    it "uses the account's OTP settings" do
      account.auth_configuration!.update!(otp_digits: 8, otp_step_seconds: 60)

      assert_api_response(:post, 201, headers: headers, path_params: path_params) do
        expect(parsed_body).to include("otp_type" => "totp", "digits" => 8, "step_seconds" => 60)
      end
    end

    it "sets up a hardware token when the account uses HOTP" do
      account.auth_configuration!.update!(otp_method: "hotp")

      assert_api_response(:post, 201, headers: headers, path_params: path_params) do
        expect(parsed_body["provisioning_uri"]).to start_with("otpauth://hotp/")
      end
    end

    it "doesn't let users choose a different method" do
      assert_api_response :post, 422, headers: headers, body: { otp_type: "hotp" }, path_params: path_params do
        expect(parsed_body.dig("error", "details")).to include({ "field" => "otp_type", "message" => "is not allowed" })
      end
    end

    it "refuses when MFA is already on" do
      user = create(:user, :with_mfa, account: account)

      assert_api_response :post, 409, headers: auth_headers_for(user), path_params: path_params
    end

    context "when turning MFA off" do
      let(:user) { create(:user, :with_mfa, account: account) }

      it "removes the authenticator" do
        assert_api_response :delete, 204, headers: headers, body: { current_password: "correct horse battery staple", code: current_totp_for(user) },
          path_params: path_params

        expect(user.reload).not_to be_mfa_enabled
      end

      it "refuses when the account requires MFA" do
        account.auth_configuration!.update!(mfa_requirement: "required")

        assert_api_response :delete, 403, headers: headers, body: { current_password: "correct horse battery staple", code: current_totp_for(user) },
          path_params: path_params
      end
    end
  end

  describe "confirming enrolment" do
    api_path "/v1/accounts/{account_uid}/me/otp/confirm" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Confirm the authenticator app with a code" do
        tags "Me"
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

    let!(:enrollment) { Mfa::OtpEnrollment.new(user: user).start }

    it "turns MFA on and returns recovery codes" do
      assert_api_response :post, 200, headers: headers, body: { code: ROTP::TOTP.new(enrollment.secret).now }, path_params: path_params

      expect(user.reload).to be_mfa_enabled
    end

    it "rejects a wrong code" do
      assert_api_response :post, 401, headers: headers, body: { code: "000000" }, path_params: path_params
    end
  end
end
