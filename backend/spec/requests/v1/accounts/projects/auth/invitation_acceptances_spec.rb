require "rails_helper"
require "openapi_helper"

RSpec.describe "End-user invitation acceptance", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/accounts/{account_uid}/projects/{project_uid}/auth/accept-invitation" do
    parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
    parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

    post "Set a first password with the code or link token from an invitation" do
      tags "End-user auth"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: EndUserAuth::AcceptInvitationRequest.as_schema } }

      response 204, "password set; the end user can sign in"

      response 400, "wrong, expired or already used invitation" do
        schema Schemas::Error
      end
    end
  end

  let(:project) { create(:project) }
  let(:app_client) { create(:app_client, project: project) }
  let(:end_user) { create(:end_user, :invited, project: project) }
  let!(:issued) { OneTimeToken.issue_with_code!(subject: end_user, purpose: :invitation) }

  def accept(status, fields)
    assert_api_response :post, status, body: { client_id: app_client.uid, password: "my first password", **fields }, path_params: project_path_params(project)
  end

  it "sets the password and verifies the email" do
    accept(204, email: end_user.email, code: issued.code)

    expect(end_user.reload).to have_attributes(password_set?: true, email_verified?: true)
  end

  it "lets the end user sign in afterwards" do
    accept(204, token: issued.token)

    result = Auth::SignIn.new(realm: project.realm, app_client: app_client).call(email: end_user.email, password: "my first password")
    expect(result.tokens).to be_present
  end

  it "only works once" do
    accept(204, token: issued.token)

    accept(400, token: issued.token)
  end
end
