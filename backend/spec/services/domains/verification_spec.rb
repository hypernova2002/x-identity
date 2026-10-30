require "rails_helper"

RSpec.describe Domains::Verification do
  let(:project) { create(:project) }
  let(:domain) { project.domains.create!(hostname: "login.acme.com") }
  let(:records) { { txt: [ domain.verification_token ], cname: "domains.x-identity.localhost" } }
  let(:resolver) do
    instance_double(Domains::DnsResolver).tap do |double|
      allow(double).to receive(:txt) { records[:txt] }
      allow(double).to receive(:cname) { records[:cname] }
    end
  end

  def verify
    described_class.new(domain, resolver: resolver).call
  end

  it "verifies a domain with both records, and records it" do
    verify

    expect(domain).to have_attributes(status: "verified", check_error: nil, check_attempts: 1)
    expect(domain.verified_at).to be_present
    expect(AuditEvent.last).to have_attributes(action: "domain.verified", target_uid: domain.uid)
  end

  it "keeps a domain pending, saying what's wrong, while records are missing or wrong" do
    records[:txt] = [ "something else" ]
    expect(verify).to have_attributes(status: "pending", check_error: "missing_txt_record", check_error_params: { "name" => "_x-identity.login.acme.com" })

    records[:txt] = [ domain.verification_token ]
    records[:cname] = "elsewhere.example.com"
    expect(verify).to have_attributes(
      status: "pending", check_error: "cname_mismatch",
      check_error_params: { "hostname" => "login.acme.com", "found" => "elsewhere.example.com", "target" => "domains.x-identity.localhost" }
    )

    records[:cname] = nil
    expect([ verify.check_error, verify.check_error_params ]).to eq([ "missing_cname", { "hostname" => "login.acme.com" } ])
  end

  it "fails a domain still unverified after 72 hours" do
    records[:txt] = []

    travel(73.hours) { verify }

    expect(domain).to have_attributes(status: "failed")
    expect(AuditEvent.last).to have_attributes(action: "domain.failed", target_uid: domain.uid)
  end

  it "lets the new domain replace the project's verified one" do
    old = project.domains.create!(hostname: "auth.acme.com", status: "verified", verified_at: 1.day.ago)

    verify

    expect(ProjectDomain.exists?(old.id)).to be(false)
    expect(project.domains.status_verified.sole).to eq(domain)
    expect(AuditEvent.where(action: "domain.removed").sole).to have_attributes(target_uid: old.uid, metadata: include("replaced_by" => "login.acme.com"))
  end

  it "keeps a verified domain verified when its records go missing, flagging it until they're back" do
    domain.update!(status: "verified", verified_at: 1.day.ago)
    records[:cname] = nil

    verify
    missing_since = domain.dns_missing_since
    expect(domain).to have_attributes(status: "verified", check_error: be_present)
    expect(missing_since).to be_present

    travel(1.hour) { verify }
    expect(domain.dns_missing_since).to eq(missing_since)

    records[:cname] = "domains.x-identity.localhost"
    verify
    expect(domain).to have_attributes(dns_missing_since: nil, check_error: nil)
  end

  it "verifies .localhost domains without DNS outside production" do
    local = project.domains.create!(hostname: "login.acme.localhost")

    described_class.new(local, resolver: instance_double(Domains::DnsResolver)).call

    expect(local).to be_status_verified
  end
end
