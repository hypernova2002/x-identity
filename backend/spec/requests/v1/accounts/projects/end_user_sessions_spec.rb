require "rails_helper"
require "openapi_helper"

RSpec.describe "An end user's devices (admin)", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
  let(:end_user) { create(:end_user, project: project) }
  let!(:device) { signed_in_device(end_user, app_client: create(:app_client, project: project)).first }

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{end_user_uid}/sessions" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :end_user_uid, in: :path, required: true, schema: { type: :string }

      get "List the devices an end user is signed in on" do
        tags "End users"
        security [ { BearerAuth: [] } ]
        ListParameters.build(search: "Device name, IP address, city or country code", sorts: %w[last_seen_at created_at]).each { |list_parameter| parameter(**list_parameter) }

        response 200, "signed-in devices, most recently active first" do
          schema type: :array, items: Schemas::DeviceSession
        end

        response 403, "only project admins and developers can see devices" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { project_path_params(project, end_user_uid: end_user.uid) }

    it "lists the end user's devices for developers" do
      assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: path_params) do
        expect(parsed_body.sole).to include("uid" => device.uid, "current" => false)
      end
    end

    it "searches by device, address or place" do
      signed_in_device(end_user, app_client: create(:app_client, project: project), ip: "198.51.100.77", user_agent: "curl/8.4.0")

      assert_api_response(:get, 200, headers: auth_headers_for(developer), params: { q: { search: "198.51.100" } }, path_params: path_params) do
        expect(parsed_body.pluck("ip")).to eq([ "198.51.100.77" ])
      end
    end

    it "is hidden from viewers" do
      assert_api_response :get, 403, headers: auth_headers_for(viewer), path_params: path_params
    end
  end

  describe "one device" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/end-users/{end_user_uid}/sessions/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :end_user_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Sign an end user out of one device" do
        tags "End users"
        security [ { BearerAuth: [] } ]

        response 204, "signed out"

        response 404, "not one of this end user's devices" do
          schema Schemas::Error
        end
      end
    end

    it "signs the device out and records who did it" do
      assert_api_response :delete, 204, headers: auth_headers_for(developer), path_params: project_path_params(project, end_user_uid: end_user.uid, uid: device.uid)

      expect(device.reload).to be_revoked
      expect(AuditEvent.last).to have_attributes(action: "end_user.device_signed_out", actor_uid: developer.uid, target_uid: end_user.uid)
    end

    it "only finds the end user's own devices" do
      other, = signed_in_device(create(:end_user, project: project), app_client: create(:app_client, project: project))

      assert_api_response :delete, 404, headers: auth_headers_for(developer), path_params: project_path_params(project, end_user_uid: end_user.uid, uid: other.uid)
    end
  end
end
