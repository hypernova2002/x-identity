require "rails_helper"
require "openapi_helper"

RSpec.describe "Account lookup", type: :openapi do
  openapi_schema :public_api

  api_path "/v1/account-lookup/{slug}" do
    parameter name: :slug, in: :path, required: true, schema: { type: :string }

    get "Find an account by its alias" do
      tags "Sign in"

      response 200, "account found" do
        schema type: :object, required: %w[uid name slug passkeys], properties: {
          uid: { type: :string }, name: { type: :string }, slug: { type: :string },
          passkeys: { type: :boolean, description: "Whether console users can sign in with passkeys." }
        }
      end

      response 404, "no account with this alias" do
        schema Schemas::Error
      end
    end
  end

  it "returns the account's uid and name" do
    account = create(:account, slug: "acme")

    assert_api_response :get, 200, path_params: { slug: "ACME" } do
      expect(parsed_body["uid"]).to eq(account.uid)
    end
  end

  it "returns not_found for an unknown alias" do
    assert_api_response :get, 404, path_params: { slug: "nobody" }
  end
end
