require "rails_helper"
require "openapi_helper"

RSpec.describe "Audit events", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/audit-events" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }

    get "List the account's audit events, newest first" do
      tags "Audit log"
      security [ { BearerAuth: [] } ]
      parameter name: :q, in: :query, style: :deepObject, explode: true, schema: {
        type: :object,
        properties: {
          action_eq: { type: :string },
          action_start: { type: :string, description: "Action prefix, e.g. `user.`" },
          actor_uid_eq: { type: :string },
          target_uid_eq: { type: :string },
          app_client_uid_eq: { type: :string },
          occurred_at_gteq: { type: :string, format: "date-time" },
          occurred_at_lteq: { type: :string, format: "date-time" }
        }
      }

      response 200, "audit events" do
        schema type: :array, items: Schemas::AuditEvent
      end

      response 403, "only account owners and admins can read the audit log" do
        schema Schemas::Error
      end
    end
  end

  let(:account) { create(:account) }
  let(:admin) { create(:user, :admin, account: account) }
  let(:recorder) { AuditEvents::Recorder.new(account: account) }

  it "lists only this account's events" do
    recorder.record(action: "user.signed_in", actor: admin)
    AuditEvents::Recorder.new(account: create(:account)).record(action: "user.signed_in")

    assert_api_response(:get, 200, headers: auth_headers_for(admin), path_params: { account_uid: account.uid }) do
      expect(parsed_body.size).to eq(1)
    end
  end

  it "filters by action" do
    recorder.record(action: "user.signed_in", actor: admin)
    recorder.record(action: "project.created", actor: admin)

    assert_api_response :get, 200, headers: auth_headers_for(admin), params: { q: { action_eq: "project.created" } },
      path_params: { account_uid: account.uid } do
      expect(parsed_body.pluck("action")).to eq([ "project.created" ])
    end
  end

  it "leaves out events that belong to a project's own log" do
    project = create(:project, account: account)
    recorder.record(action: "project.member_added", actor: admin, project: project)
    recorder.record(action: "user.signed_in", actor: admin)

    assert_api_response :get, 200, headers: auth_headers_for(admin), path_params: { account_uid: account.uid } do
      expect(parsed_body.pluck("action")).to eq([ "user.signed_in" ])
    end
  end

  it "is hidden from members" do
    assert_api_response :get, 403, headers: auth_headers_for(create(:user, account: account)), path_params: { account_uid: account.uid }
  end
end
