require "rails_helper"

RSpec.describe DomainVerificationJob do
  let(:domain) { create(:project).domains.create!(hostname: "login.acme.com") }

  before { allow(Domains::DnsResolver).to receive(:new).and_return(instance_double(Domains::DnsResolver, txt: [], cname: nil)) }

  it "checks again later, backing off, while the domain is pending" do
    freeze_time do
      expect { described_class.perform_now(domain_id: domain.id) }
        .to have_enqueued_job(described_class).with(domain_id: domain.id).at(1.minute.from_now)

      domain.update!(check_attempts: 7)
      expect { described_class.perform_now(domain_id: domain.id) }
        .to have_enqueued_job(described_class).with(domain_id: domain.id).at(1.hour.from_now)
    end
  end

  it "stops once the domain is verified or gone" do
    allow(Domains::DnsResolver).to receive(:new).and_return(instance_double(Domains::DnsResolver, txt: [ domain.verification_token ], cname: "domains.x-identity.localhost"))

    expect { described_class.perform_now(domain_id: domain.id) }.not_to have_enqueued_job(described_class)
    expect(domain.reload).to be_status_verified
    expect { described_class.perform_now(domain_id: 0) }.not_to have_enqueued_job(described_class)
  end
end

RSpec.describe CheckDomainsJob do
  it "re-checks pending and verified domains of active projects" do
    pending = create(:project).domains.create!(hostname: "login.one.localhost")
    verified = create(:project).domains.create!(hostname: "login.two.localhost", status: "verified", verified_at: 1.day.ago)
    deleted = create(:project, deleted_at: 1.hour.ago).domains.create!(hostname: "login.three.localhost")

    described_class.perform_now

    expect(pending.reload).to be_status_verified
    expect(verified.reload.last_checked_at).to be_present
    expect(deleted.reload).to be_status_pending
  end
end
