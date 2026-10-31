require "rails_helper"

RSpec.describe Domains::DnsResolver do
  let(:resolver) { described_class.new }
  let(:dns) { instance_double(Resolv::DNS, :timeouts= => nil) }

  before { allow(Resolv::DNS).to receive(:open).and_yield(dns) }

  it "reads TXT records, joining each record's strings" do
    record = instance_double(Resolv::DNS::Resource::IN::TXT, strings: [ "x-identity-", "verify=abc" ])
    allow(dns).to receive(:getresources).with("_x-identity.login.acme.com", Resolv::DNS::Resource::IN::TXT).and_return([ record ])

    expect(resolver.txt("_x-identity.login.acme.com")).to eq([ "x-identity-verify=abc" ])
    expect(dns).to have_received(:timeouts=).with(described_class::TIMEOUT_SECONDS)
  end

  it "reads the CNAME target in lower case, without the trailing dot, or nothing" do
    record = instance_double(Resolv::DNS::Resource::IN::CNAME, name: Resolv::DNS::Name.create("Domains.X-Identity.Example."))
    allow(dns).to receive(:getresources).and_return([ record ], [])

    expect(resolver.cname("login.acme.com")).to eq("domains.x-identity.example")
    expect(resolver.cname("login.acme.com")).to be_nil
  end

  it "reads failed lookups as no records" do
    allow(Resolv::DNS).to receive(:open).and_raise(Resolv::ResolvError)

    expect(resolver.txt("login.acme.com")).to be_nil
    expect(resolver.cname("login.acme.com")).to be_nil
  end
end
