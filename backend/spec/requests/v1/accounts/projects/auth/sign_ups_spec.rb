require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user sign-up", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/sign-up" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    post "Sign up an end user" do
      tags "End-user auth"
      description "Always responds 202, whether or not the email is already registered. New and unconfirmed " \
        "addresses get a confirmation code; confirmed ones get an email saying they already have an account."
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: EndUserAuth::SignUpRequest.as_schema } }

      response 202, "accepted; check your email"

      response 401, "unknown or disabled app client, or wrong client secret" do
        schema Schemas::Error
      end

      response 403, "self sign-up is turned off" do
        schema Schemas::Error
      end

      response 422, "invalid email, password or attributes" do
        schema Schemas::Error
      end
    end
  end

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:body) { { client_id: app_client.uid, email: "Casey@Shop.test", password: "correct horse battery staple", name: "Casey" } }

  def sign_up(status, request_body = body, &block)
    assert_api_response(:post, status, body: request_body, path_params: project_path_params(project), &block)
  end

  it "queues the sign-up without revealing anything" do
    expect { sign_up(202) }.to have_enqueued_job(EndUserSignUpJob).with(hash_including(project_id: project.id, email: "casey@shop.test"))
  end

  it "never queues the plaintext password" do
    sign_up(202)

    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.inspect).not_to include("correct horse battery staple")
  end

  it "responds the same way for an email that is already registered" do
    create(:end_user, project: project, email: "casey@shop.test")

    sign_up(202)
  end

  it "rejects an unknown app client" do
    sign_up(401, body.merge(client_id: "cl_unknown")) { expect(error_code).to eq("invalid_client") }
  end

  it "rejects an app client from another project" do
    sign_up(401, body.merge(client_id: create(:app_client).uid))
  end

  it "rejects a disabled app client" do
    app_client.update!(enabled: false)

    sign_up(401)
  end

  it "requires the secret of a confidential client" do
    confidential = create(:app_client, :confidential, project: project)

    sign_up(401, body.merge(client_id: confidential.uid))
  end

  it "accepts a confidential client with its secret" do
    confidential = create(:app_client, :confidential, project: project)

    sign_up(202, body.merge(client_id: confidential.uid, client_secret: "client-secret-for-specs"))
  end

  it "refuses when self sign-up is turned off" do
    project.update!(allow_self_sign_up: false)

    sign_up(403) { expect(error_code).to eq("sign_up_disabled") }
  end

  it "applies the project's password rules" do
    project.auth_configuration!.update!(password_min_length: 40)

    sign_up(422) { expect(parsed_body.dig("error", "details", 0, "field")).to eq("password") }
  end

  it "rejects unknown fields" do
    sign_up(422, body.merge(admin: true)) do
      expect(parsed_body.dig("error", "details")).to include(include("field" => "admin", "code" => "not_allowed"))
    end
  end

  context "with custom attributes" do
    before do
      create(:end_user_attribute_definition, project: project, key: "plan", data_type: "string", required: true)
      create(:end_user_attribute_definition, project: project, key: "credit", data_type: "number", user_editable: false)
    end

    it "requires required attributes" do
      sign_up(422) { expect(parsed_body.dig("error", "details")).to include(include("field" => "custom_attributes.plan", "code" => "required")) }
    end

    it "accepts valid attributes" do
      sign_up(202, body.merge(custom_attributes: { plan: "pro" }))
    end

    it "refuses attributes end users may not set" do
      sign_up(422, body.merge(custom_attributes: { plan: "pro", credit: 100 })) do
        expect(parsed_body.dig("error", "details")).to include(include("field" => "custom_attributes.credit", "code" => "not_user_editable"))
      end
    end
  end
end
