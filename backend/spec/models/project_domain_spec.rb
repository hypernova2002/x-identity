require "rails_helper"

RSpec.describe ProjectDomain do
  let(:project) { create(:project) }

  it "normalises the hostname and generates a verification token" do
    domain = project.domains.create!(hostname: " Login.Acme.COM. ")

    expect(domain).to have_attributes(hostname: "login.acme.com", status: "pending", certificate_status: "external")
    expect(domain.verification_token).to match(/\A\h{40}\z/)
    expect(domain.txt_record_name).to eq("_x-identity.login.acme.com")
  end

  it "accepts only hostnames" do
    %w[https://login.acme.com login.acme.com/path login acme..com -login.acme.com 10.0.0.1].each do |hostname|
      expect(project.domains.new(hostname: hostname)).not_to be_valid, hostname
    end
  end

  it "refuses x-identity's own hosts and domains another project uses" do
    expect(project.domains.new(hostname: "domains.x-identity.localhost")).not_to be_valid
    expect(project.domains.new(hostname: "acme.domains.x-identity.localhost")).not_to be_valid

    create(:project).domains.create!(hostname: "login.acme.com")
    expect(project.domains.new(hostname: "login.acme.com")).not_to be_valid
  end

  it "allows .localhost domains except in production" do
    expect(project.domains.new(hostname: "login.acme.localhost")).to be_valid

    allow(Rails.env).to receive(:production?).and_return(true)
    expect(project.domains.new(hostname: "login.acme.localhost")).not_to be_valid
  end

  it "serves .localhost domains over http, on the edge proxy's port when there is one" do
    domain = project.domains.new(hostname: "login.acme.localhost")
    configured = Rails.configuration.x.custom_domain_local_port

    Rails.configuration.x.custom_domain_local_port = "8080"
    expect(domain.base_url).to eq("http://login.acme.localhost:8080")
    Rails.configuration.x.custom_domain_local_port = nil
    expect(domain.base_url).to eq("http://login.acme.localhost")
    expect(project.domains.new(hostname: "login.acme.com").base_url).to eq("https://login.acme.com")
  ensure
    Rails.configuration.x.custom_domain_local_port = configured
  end

  it "skips the reserved-host checks for a missing hostname" do
    expect(error_codes(project.domains.new(hostname: ""), :hostname)).to contain_exactly(:blank, :invalid)
  end
end
