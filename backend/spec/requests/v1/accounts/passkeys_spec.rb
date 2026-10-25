require "rails_helper"
require "openapi_helper"
require "webauthn/fake_client"

RSpec.describe "Passkeys", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:console) { URI.parse(Rails.configuration.x.console_base_url) }
  let(:console_origin) { "#{console.scheme}://#{console.host}:#{console.port}" }
  let(:path_params) { { account_uid: account.uid } }

  def turn_on_passkeys(owner)
    owner.auth_configuration!.update!(passkeys: "optional")
  end

  # Asks for options, and has a fake authenticator create a passkey from them, as a browser would.
  def new_passkey(headers:, origin:, rp_id:, path: "/v1/accounts/#{account.uid}/me/passkeys", user_verified: true, synced: true)
    post "#{path}/options", headers: headers
    options = response.parsed_body
    expect(options.dig("public_key", "rp", "id")).to eq(rp_id)
    credential = WebAuthn::FakeClient.new(origin, encoding: :base64url)
      .create(challenge: options.dig("public_key", "challenge"), rp_id: rp_id, user_verified: user_verified, backup_eligibility: synced)
    { registration_id: options["registration_id"], credential: credential }
  end

  describe "a console user's own passkeys" do
    api_path "/v1/accounts/{account_uid}/me/passkeys/options" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      post "Start adding a passkey" do
        tags "My security"
        security [ { BearerAuth: [] } ]

        response 200, "options for navigator.credentials.create, and the registration to send back" do
          schema Schemas::PasskeyRegistrationOptions
        end

        response 403, "the last sign-in was more than 15 minutes ago" do
          schema Schemas::Error
        end

        response 409, "passkeys aren't turned on for console users" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/me/passkeys" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "List my passkeys" do
        tags "My security"
        security [ { BearerAuth: [] } ]

        response 200, "passkeys, oldest first" do
          schema type: :array, items: Schemas::Passkey
        end
      end

      post "Save the passkey the browser created" do
        tags "My security"
        security [ { BearerAuth: [] } ]
        request_body required: true, content: { "application/json" => { schema: Passkeys::FinishRegistrationRequest.as_schema } }

        response 201, "saved" do
          schema Schemas::Passkey
        end

        response 400, "the passkey couldn't be verified, e.g. the user didn't unlock it, or the registration was used or expired" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/me/passkeys/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      patch "Rename a passkey" do
        tags "My security"
        security [ { BearerAuth: [] } ]
        request_body required: true, content: { "application/json" => { schema: Passkeys::RenameRequest.as_schema } }

        response 200, "renamed" do
          schema Schemas::Passkey
        end
      end

      delete "Remove a passkey" do
        tags "My security"
        security [ { BearerAuth: [] } ]

        response 204, "removed"
      end
    end

    it "aren't offered until passkeys are turned on" do
      assert_api_response :post, 409, headers: auth_headers_for(user), path_params: path_params
    end

    context "when passkeys are turned on" do
      before { turn_on_passkeys(account) }

      it "adds a passkey for the console's host, named after the device" do
        headers = auth_headers_for(user).merge("User-Agent" => CHROME_ON_MAC)
        body = new_passkey(headers: headers, origin: console_origin, rp_id: console.host)

        assert_api_response(:post, 201, headers: headers, path_params: path_params, body: body) do
          expect(parsed_body).to include("name" => "Chrome on Mac", "domain" => console.host, "synced" => true, "last_used_at" => nil)
        end
        expect(user.webauthn_credentials.sole.public_key).to be_present
        expect(user.reload.webauthn_id).to be_present
        expect(AuditEvent.last).to have_attributes(action: "user.passkey_added", actor_uid: user.uid)
      end

      it "refuses passkeys the user didn't unlock, and registrations used twice" do
        headers = auth_headers_for(user)
        unverified = new_passkey(headers: headers, origin: console_origin, rp_id: console.host, user_verified: false)
        assert_api_response :post, 400, headers: headers, path_params: path_params, body: unverified

        body = new_passkey(headers: headers, origin: console_origin, rp_id: console.host)
        post "/v1/accounts/#{account.uid}/me/passkeys", params: body, headers: headers, as: :json
        expect(response).to have_http_status(:created)
        post "/v1/accounts/#{account.uid}/me/passkeys", params: body, headers: headers, as: :json
        expect(error_code).to eq("invalid_passkey")
      end

      it "refuses passkeys made for another site" do
        headers = auth_headers_for(user)
        body = new_passkey(headers: headers, origin: "https://evil.example.com", rp_id: console.host)

        post "/v1/accounts/#{account.uid}/me/passkeys", params: body, headers: headers, as: :json
        expect(error_code).to eq("invalid_passkey")
      end

      it "needs a sign-in in the last 15 minutes" do
        tokens = Auth::TokenIssuer.new(realm: user.realm).issue(user: user, authenticated_at: 16.minutes.ago, amr: [ "pwd" ])

        assert_api_response :post, 403, headers: { "Authorization" => "Bearer #{tokens.access_token}" }, path_params: path_params
        expect(error_code).to eq("reauthentication_required")
      end

      it "lists, renames and removes passkeys" do
        headers = auth_headers_for(user)
        post "/v1/accounts/#{account.uid}/me/passkeys", params: new_passkey(headers: headers, origin: console_origin, rp_id: console.host), headers: headers, as: :json
        passkey = user.webauthn_credentials.sole

        assert_api_response(:get, 200, headers: headers, path_params: path_params) { expect(parsed_body.sole["uid"]).to eq(passkey.uid) }
        assert_api_response(:patch, 200, headers: headers, path_params: path_params.merge(uid: passkey.uid), body: { name: "Work laptop" }) do
          expect(parsed_body["name"]).to eq("Work laptop")
        end
        assert_api_response :delete, 204, headers: headers, path_params: path_params.merge(uid: passkey.uid)

        expect(user.webauthn_credentials).to be_empty
        expect(AuditEvent.order(:id).last(2).map(&:action)).to eq(%w[user.passkey_renamed user.passkey_removed])
      end
    end
  end

  describe "an end user's own passkeys" do
    let(:project) { create(:project, account: account) }
    let(:app_client) { create(:app_client, project: project) }
    let(:end_user) { create(:end_user, project: project) }
    let(:headers) { { "Authorization" => "Bearer #{tokens_for(end_user, app_client: app_client).access_token}" } }

    before { turn_on_passkeys(project) }

    it "need the project's custom domain" do
      post "#{URI.parse(project.token_issuer).path}/me/passkeys/options", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "message")).to eq("Passkeys work on the project's custom domain, and from its apps' allowed origins.")
    end

    it "belong to the custom domain" do
      project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
      host! "login.acme.com"
      https!

      body = new_passkey(headers: headers, origin: "https://login.acme.com", rp_id: "login.acme.com", path: "/me/passkeys")
      post "/me/passkeys", params: body, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(end_user.webauthn_credentials.sole.rp_id).to eq("login.acme.com")
      expect(AuditEvent.last.action).to eq("end_user.passkey_added")
    end

    it "are removed by an admin's Reset MFA" do
      end_user.webauthn_credentials.create!(external_id: "abc", public_key: "key", rp_id: "login.acme.com", name: "Phone")
      admin = create(:user, :admin, account: account)

      EndUsers::Management.new(actor: admin, project: project).reset_mfa(end_user)

      expect(end_user.webauthn_credentials.reload).to be_empty
    end
  end
end

RSpec.describe Auth::Factors do
  it "counts one-time codes and unlocked passkeys as multi-factor" do
    expect(described_class.mfa?(%w[pwd otp])).to be(true)
    expect(described_class.mfa?(%w[hwk user])).to be(true)
    expect(described_class.mfa?(%w[swk user])).to be(true)
    expect(described_class.mfa?(%w[hwk])).to be(false)
    expect(described_class.mfa?(%w[pwd])).to be(false)
  end
end
