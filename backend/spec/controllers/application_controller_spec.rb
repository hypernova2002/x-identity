require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def invalid
      raise ActiveRecord::RecordInvalid, Project.new.tap(&:validate)
    end

    def duplicate
      raise ActiveRecord::RecordNotUnique
    end

    def missing
      params.require(:name)
    end
  end

  before do
    routes.draw do
      get "invalid" => "anonymous#invalid"
      get "duplicate" => "anonymous#duplicate"
      get "missing" => "anonymous#missing"
    end
  end

  it "answers a record that failed validation with its field errors" do
    get :invalid

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    expect(response.parsed_body.dig("error", "details").pluck("field")).to include("name")
  end

  it "answers a unique index violation as a conflict" do
    get :duplicate

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig("error", "code")).to eq("conflict")
  end

  it "answers a missing parameter as a required field" do
    get :missing

    expect(response.parsed_body.dig("error", "details", 0)).to include("field" => "name", "code" => "required")
  end

  it "skips empty entries in Accept-Language" do
    request.headers["Accept-Language"] = ", ja;q=0.5"

    expect(controller.send(:request_locale)).to eq("ja")
  end
end
