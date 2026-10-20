require "rails_helper"

RSpec.describe "Unhandled errors", type: :request do
  around do |example|
    env_config = Rails.application.env_config
    original = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env_config["action_dispatch.show_detailed_exceptions"] = original
  end

  it "renders unknown routes in the standard error shape" do
    get "/does-not-exist"

    expect([ response.status, response.parsed_body ]).to eq(
      [
        404,
        { "error" => { "code" => "not_found", "message" => "The requested resource could not be found.", "details" => [] } }
      ]
    )
  end
end
