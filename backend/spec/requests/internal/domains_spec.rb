require "rails_helper"

RSpec.describe "Internal domain checks", type: :request do
  it "allows certificates only for verified domains of active projects" do
    create(:project).domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
    create(:project).domains.create!(hostname: "login.pending.com")
    create(:project, deleted_at: 1.hour.ago).domains.create!(hostname: "login.deleted.com", status: "verified", verified_at: Time.current)

    statuses = %w[LOGIN.ACME.COM. login.pending.com login.deleted.com unknown.com].map do |domain|
      get "/internal/domains/allowed", params: { domain: domain }
      response.status
    end

    expect(statuses).to eq([ 200, 404, 404, 404 ])
  end
end
