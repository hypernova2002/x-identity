require "rails_helper"
require "openapi_helper"

RSpec.describe "Auth configuration", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/auth-configuration" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    get "The account's authentication settings" do
      tags "Auth configuration"
      security [ { BearerAuth: [] } ]

      response 200, "current settings" do
        schema Schemas::AuthConfiguration
      end

      response 403, "only account owners and admins can see settings" do
        schema Schemas::Error
      end
    end

    put "Update the account's authentication settings" do
      tags "Auth configuration"
      security [ { BearerAuth: [] } ]
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: AuthConfigurations::UpdateRequest.as_schema } }

      response 200, "updated" do
        schema Schemas::AuthConfiguration
      end

      response 422, "a setting is out of range" do
        schema Schemas::Error
      end
    end
  end

  let(:account) { create(:account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:path_params) { { account_uid: account.uid } }

  it "returns the defaults for a new account" do
    assert_api_response :get, 200, headers: auth_headers_for(admin), path_params: path_params do
      expect(parsed_body).to include("mfa_requirement" => "optional", "require_email_verification" => false, "signing_algorithm" => "ES256")
    end
  end

  it "hides settings from members" do
    assert_api_response :get, 403, headers: auth_headers_for(create(:user, account: account)), path_params: path_params
  end

  it "updates settings" do
    assert_api_response :put, 200, headers: auth_headers_for(admin), body: { mfa_requirement: "required", lockout_threshold: 5 }, path_params: path_params

    expect(account.auth_configuration.reload).to have_attributes(mfa_requirement: "required", lockout_threshold: 5)
  end

  it "rejects out-of-range values" do
    assert_api_response :put, 422, headers: auth_headers_for(admin), body: { access_token_ttl_seconds: 2.hours.to_i }, path_params: path_params do
      expect(parsed_body.dig("error", "details", 0, "field")).to eq("access_token_ttl_seconds")
    end
  end

  it "rejects an unsupported signing algorithm" do
    assert_api_response :put, 422, headers: auth_headers_for(admin), body: { signing_algorithm: "HS256" }, path_params: path_params
  end

  it "signs new tokens with the newly chosen algorithm" do
    assert_api_response :put, 200, headers: auth_headers_for(admin), body: { signing_algorithm: "RS256" }, path_params: path_params

    expect(JWT.decode(tokens_for(admin.reload).access_token, nil, false).last["alg"]).to eq("RS256")
  end

  it "records the change in the audit log" do
    assert_api_response :put, 200, headers: auth_headers_for(admin), body: { lockout_threshold: 5 }, path_params: path_params

    expect(account.audit_events.last.metadata.dig("changes", "lockout_threshold")).to eq({ "from" => 10, "to" => 5 })
  end
end
