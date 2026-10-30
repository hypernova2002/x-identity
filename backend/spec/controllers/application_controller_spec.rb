require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      case params[:failure]
      when "api_error"
        raise ApiError.new(:conflict, reason: :already_group_member, params: { email: "dana@acme.test", group: "Support" })
      when "not_found"
        raise ActiveRecord::RecordNotFound
      when "parameter_missing"
        params.require(:project)
      end
    end
  end

  it "renders an ApiError with its code, reason and the reason's params" do
    get :index, params: { failure: "api_error" }

    expect([ response.status, response.parsed_body ]).to eq(
      [
        409,
        {
          "error" => {
            "code" => "conflict",
            "reason" => "already_group_member",
            "message" => "dana@acme.test is already in Support.",
            "params" => { "email" => "dana@acme.test", "group" => "Support" },
            "details" => []
          }
        }
      ]
    )
  end

  it "renders missing records as not_found" do
    get :index, params: { failure: "not_found" }

    expect(response.parsed_body.dig("error", "code")).to eq("not_found")
  end

  it "renders missing parameters as a field-level validation error" do
    get :index, params: { failure: "parameter_missing" }

    expect(response.parsed_body["error"]).to include(
      "code" => "validation_failed",
      "details" => [ { "field" => "project", "code" => "required", "message" => "is required", "params" => {} } ]
    )
  end
end
