require "rails_helper"
require "openapi_helper"

RSpec.describe "Signed-in devices (end users)", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, project: project) }
  let(:path_params) { project_path_params(project) }
  let!(:this_device) { signed_in_device(end_user, app_client: app_client) }
  let(:headers) { { "Authorization" => "Bearer #{this_device.last.access_token}" } }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/sessions" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "List the devices you're signed in on" do
        tags "End-user devices"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Device name, IP address, city or country code", sorts: %w[last_seen_at created_at]).each { |list_parameter| parameter(**list_parameter) }

        response 200, "signed-in devices, most recently active first" do
          schema type: :array, items: Schemas::DeviceSession
        end
      end

      delete "Sign out every other device" do
        tags "End-user devices"
        security [ { BearerAuth: [] } ]

        response 204, "signed out everywhere except this device"
      end
    end

    it "includes browsers signed in to the hosted login page" do
      browser, _token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current, ip: "198.51.100.4", user_agent: CHROME_ON_MAC)

      assert_api_response(:get, 200, headers: headers, path_params: path_params) do
        expect(parsed_body.pluck("uid")).to contain_exactly(this_device.first.uid, browser.device_session.uid)
      end
    end

    it "signs out other devices, including their hosted login session" do
      browser, _token = BrowserSession.start!(end_user: end_user, amr: [ "pwd" ], authenticated_at: Time.current)

      assert_api_response :delete, 204, headers: headers, path_params: path_params

      expect(browser.reload.revoked_at).to be_present
      expect(this_device.first.reload).not_to be_revoked
    end
  end

  describe "one device" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/me/sessions/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Sign out a device" do
        tags "End-user devices"
        security [ { BearerAuth: [] } ]

        response 204, "signed out"

        response 404, "not one of your devices" do
          schema Schemas::Error
        end
      end
    end

    it "signs a device out, and its refresh tokens stop working" do
      other, other_tokens = signed_in_device(end_user, app_client: app_client)

      assert_api_response :delete, 204, headers: headers, path_params: path_params.merge(uid: other.uid)

      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/auth/refresh",
        params: { client_id: app_client.uid, refresh_token: other_tokens.refresh_token }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "can't sign out another user's device" do
      theirs, = signed_in_device(create(:end_user, project: project), app_client: app_client)

      assert_api_response :delete, 404, headers: headers, path_params: path_params.merge(uid: theirs.uid)
    end
  end
end
