require "rails_helper"
require "openapi_helper"

RSpec.describe "Signed-in devices (console users)", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:path_params) { { account_uid: account.uid } }
  let!(:this_device) { signed_in_device(user) }
  let(:headers) { { "Authorization" => "Bearer #{this_device.last.access_token}" } }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/me/sessions" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

      get "List the devices you're signed in on" do
        tags "Devices"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Device name, IP address, city or country code", sorts: %w[last_seen_at created_at]).each { |list_parameter| parameter(**list_parameter) }

        response 200, "signed-in devices, most recently active first" do
          schema type: :array, items: Schemas::DeviceSession
        end
      end

      delete "Sign out every other device" do
        tags "Devices"
        security [ { BearerAuth: [] } ]

        response 204, "signed out everywhere except this device"
      end
    end

    it "lists the user's own current devices and marks this one" do
      other, = signed_in_device(user, user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1")
      signed_out, = signed_in_device(user)
      signed_out.revoke!
      signed_in_device(create(:user, account: account))

      assert_api_response(:get, 200, headers: headers, path_params: path_params) do
        expect(parsed_body.map { |row| [ row["uid"], row["current"] ] }).to contain_exactly([ this_device.first.uid, true ], [ other.uid, false ])
        expect(parsed_body.find { |row| row["current"] }).to include("device_name" => "Chrome on Mac", "ip" => "203.0.113.10", "amr" => [ "pwd" ])
      end
    end

    it "signs out every other device, keeping this one" do
      other, other_tokens = signed_in_device(user)

      assert_api_response :delete, 204, headers: headers, path_params: path_params

      expect(other.reload).to be_revoked
      expect(RefreshToken.find_by_token(other_tokens.refresh_token)).to be_revoked
      expect(RefreshToken.find_by_token(this_device.last.refresh_token)).not_to be_revoked
      expect(AuditEvent.last).to have_attributes(action: "user.other_devices_signed_out", actor_uid: user.uid)
    end
  end

  describe "one device" do
    api_path "/v1/accounts/{account_uid}/me/sessions/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Sign out a device" do
        tags "Devices"
        security [ { BearerAuth: [] } ]

        response 204, "signed out; its refresh tokens stop working, and its access tokens expire as usual"

        response 404, "not one of your devices" do
          schema Schemas::Error
        end
      end
    end

    it "signs the device out" do
      other, other_tokens = signed_in_device(user)

      assert_api_response :delete, 204, headers: headers, path_params: path_params.merge(uid: other.uid)

      expect(RefreshToken.find_by_token(other_tokens.refresh_token)).to be_revoked
      expect(AuditEvent.last).to have_attributes(action: "user.device_signed_out", metadata: include("device" => other.uid))
    end

    it "can't sign out someone else's device" do
      theirs, = signed_in_device(create(:user, account: account))

      assert_api_response :delete, 404, headers: headers, path_params: path_params.merge(uid: theirs.uid)
      expect(theirs.reload).not_to be_revoked
    end
  end
end
