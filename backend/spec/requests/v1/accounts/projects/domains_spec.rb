require "rails_helper"
require "openapi_helper"

RSpec.describe "Custom domains", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:account) { project.account }
  let(:admin) { create(:user, :admin, account: account) }
  let(:developer) { create(:user, account: account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:path_params) { project_path_params(project) }

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/domains" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    get "List the project's custom domain, and its replacement while one is being set up" do
      tags "Custom domains"
      security [ { BearerAuth: [] } ]

      response 200, "at most two domains" do
        schema type: :array, items: Schemas::ProjectDomain
      end
    end

    post "Add a custom domain, or the replacement for the current one" do
      tags "Custom domains"
      security [ { BearerAuth: [] } ]
      request_body required: true, content: { "application/json" => { schema: Domains::CreateRequest.as_schema } }

      response 201, "added; its DNS is checked until it's verified, for up to 72 hours" do
        schema Schemas::ProjectDomain
      end

      response 403, "only project and account admins manage the domain" do
        schema Schemas::Error
      end

      response 409, "another domain is still being set up" do
        schema Schemas::Error
      end

      response 422, "not a hostname, x-identity's own, or used by another project" do
        schema Schemas::Error
      end
    end
  end

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/domains/{uid}/check" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :uid, in: :path, required: true, schema: { type: :string }

    post "Check the domain's DNS records now" do
      tags "Custom domains"
      security [ { BearerAuth: [] } ]

      response 200, "the domain after the check" do
        schema Schemas::ProjectDomain
      end
    end
  end

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/domains/{uid}" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :uid, in: :path, required: true, schema: { type: :string }

    delete "Remove a custom domain" do
      tags "Custom domains"
      security [ { BearerAuth: [] } ]

      response 204, "removed"
    end
  end

  it "adds a domain with the DNS records to create, and starts checking it" do
    expect do
      assert_api_response(:post, 201, headers: auth_headers_for(admin), path_params: path_params, body: { hostname: "Login.Acme.com" }) do
        expect(parsed_body).to include("hostname" => "login.acme.com", "status" => "pending")
        expect(parsed_body["dns_records"]).to eq([
          { "type" => "CNAME", "name" => "login.acme.com", "value" => "domains.x-identity.localhost" },
          { "type" => "TXT", "name" => "_x-identity.login.acme.com", "value" => project.domains.sole.verification_token }
        ])
      end
    end.to have_enqueued_job(DomainVerificationJob)

    expect(AuditEvent.last).to have_attributes(action: "domain.added", actor_uid: admin.uid)
  end

  it "lets developers see the domain but not change it" do
    project.domains.create!(hostname: "login.acme.com")

    assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: path_params) { expect(parsed_body.sole["hostname"]).to eq("login.acme.com") }
    assert_api_response :post, 403, headers: auth_headers_for(developer), path_params: path_params, body: { hostname: "auth.acme.com" }
  end

  it "allows one domain being set up at a time" do
    project.domains.create!(hostname: "login.acme.com")

    assert_api_response :post, 409, headers: auth_headers_for(admin), path_params: path_params, body: { hostname: "auth.acme.com" }
  end

  it "refuses anything but a hostname" do
    assert_api_response :post, 422, headers: auth_headers_for(admin), path_params: path_params, body: { hostname: "https://login.acme.com" }
  end

  it "checks DNS on request" do
    domain = project.domains.create!(hostname: "login.acme.localhost")

    assert_api_response(:post, 200, headers: auth_headers_for(admin), path_params: path_params.merge(uid: domain.uid)) do
      expect(parsed_body["status"]).to eq("verified")
    end
  end

  it "removes a domain" do
    domain = project.domains.create!(hostname: "login.acme.com")

    assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params.merge(uid: domain.uid)

    expect(project.domains.reload).to be_empty
    expect(AuditEvent.last).to have_attributes(action: "domain.removed", target_uid: domain.uid)
  end
end
