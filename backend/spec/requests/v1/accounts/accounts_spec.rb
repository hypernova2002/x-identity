require "rails_helper"
require "openapi_helper"

RSpec.describe "Accounts", type: :openapi do
  openapi_schema :public_api

  let(:account) { create(:account, name: "Acme") }
  let(:admin) { create(:user, :admin, account: account) }
  let(:member) { create(:user, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  api_path "/v1/accounts/{account_uid}" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    get "Get the account" do
      tags "Accounts"
      security [ { BearerAuth: [] } ]

      response 200, "the account" do
        schema Schemas::Account
      end
    end

    patch "Rename the account" do
      tags "Accounts"
      security [ { BearerAuth: [] } ]
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: Accounts::UpdateRequest.as_schema } }

      response 200, "updated" do
        schema Schemas::Account
      end

      response 403, "only admins and owners can rename the account" do
        schema Schemas::Error
      end

      response 422, "the name is invalid" do
        schema Schemas::Error
      end
    end
  end

  it "shows the account to its users" do
    assert_api_response :get, 200, headers: auth_headers_for(member), path_params: path_params do
      expect(parsed_body).to include("uid" => account.uid, "name" => "Acme")
    end
  end

  it "lets admins rename the account, and records it" do
    assert_api_response :patch, 200, headers: auth_headers_for(admin), body: { name: "Acme Inc" }, path_params: path_params do
      expect(parsed_body).to include("name" => "Acme Inc")
    end
    expect(AuditEvent.last).to have_attributes(action: "account.updated", actor_uid: admin.uid)
  end

  it "doesn't let members rename the account" do
    assert_api_response :patch, 403, headers: auth_headers_for(member), body: { name: "Acme Inc" }, path_params: path_params
  end

  it "refuses an invalid name" do
    assert_api_response :patch, 422, headers: auth_headers_for(admin), body: { name: "" }, path_params: path_params
  end
end
