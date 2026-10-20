require "rails_helper"
require "openapi_helper"

RSpec.describe "Sign up", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/sign-up" do
    post "Create an account and its first owner" do
      tags "Sign up"
      consumes "application/json"
      request_body required: true, content: { "application/json" => { schema: SignUpRequest.as_schema } }

      response 201, "account created" do
        schema type: :object, required: %w[account user], properties: { account: Schemas::Account, user: Schemas::User }
      end

      response 422, "invalid input" do
        schema Schemas::Error
      end
    end
  end

  let(:body) do
    { account_name: "Acme", slug: "acme", name: "Dana", email: "dana@acme.test", password: "correct horse battery staple" }
  end

  it "creates the account with the user as owner" do
    assert_api_response :post, 201, body: body do
      expect(User.find_by!(uid: parsed_body.dig("user", "uid"))).to have_attributes(role: "owner", account: Account.find_by!(slug: "acme"))
    end
  end

  it "sends a verification email" do
    expect { assert_api_response :post, 201, body: body }.to have_enqueued_job(VerificationEmailJob).with(
      account_id: kind_of(Integer), email: "dana@acme.test"
    )
  end

  it "creates the account's auth configuration" do
    assert_api_response :post, 201, body: body

    expect(Account.find_by!(slug: "acme").auth_configuration).to be_present
  end

  it "allows the same email in a different account" do
    create(:user, email: "dana@acme.test")

    assert_api_response :post, 201, body: body
  end

  it "rejects a slug that is already taken" do
    create(:account, slug: "acme")

    assert_api_response :post, 422, body: body do
      expect(parsed_body.dig("error", "details")).to include({ "field" => "slug", "message" => "has already been taken" })
    end
  end

  it "rejects a password that breaks the default rules" do
    assert_api_response :post, 422, body: body.merge(password: "short") do
      expect(parsed_body.dig("error", "details").pluck("field")).to eq([ "password" ])
    end
  end

  it "reports account field errors under the request field names" do
    assert_api_response :post, 422, body: body.merge(account_name: "") do
      expect(parsed_body.dig("error", "details").pluck("field")).to include("account_name")
    end
  end
end
