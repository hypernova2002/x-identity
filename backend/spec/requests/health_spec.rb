require "rails_helper"

RSpec.describe "Health check", type: :request do
  it "answers when the app has booted, for load balancers and uptime monitors" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
