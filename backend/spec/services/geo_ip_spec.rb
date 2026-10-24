require "rails_helper"

RSpec.describe GeoIp do
  let(:records) do
    {
      "81.17.240.1" => {
        "city" => { "names" => { "en" => "Dublin" } },
        "subdivisions" => [ { "names" => { "en" => "Leinster" } } ],
        "country" => { "iso_code" => "IE", "names" => { "en" => "Ireland" } }
      },
      "198.51.100.7" => { "country" => { "iso_code" => "NL" } }
    }
  end
  let(:reader) { Struct.new(:records) { def get(ip) = records[ip] }.new(records) }
  let(:geo_ip) { described_class.new(reader) }

  it "reads the city, region and country from a GeoIP2 city record" do
    expect(geo_ip.lookup("81.17.240.1")).to eq(GeoIp::Location.new(city: "Dublin", region: "Leinster", country_code: "IE"))
  end

  it "keeps what the database knows when it only knows the country" do
    expect(geo_ip.lookup("198.51.100.7")).to eq(GeoIp::Location.new(city: nil, region: nil, country_code: "NL"))
  end

  it "has no location for private, loopback or unparseable addresses, or unknown ones" do
    expect([ "10.1.2.3", "192.168.0.4", "127.0.0.1", "::1", "fe80::1", "not an ip", nil, "203.0.113.99" ].map { |ip| geo_ip.lookup(ip) }).to all(be_nil)
  end

  it "has no location without a database" do
    expect(described_class.new(nil).lookup("81.17.240.1")).to be_nil
    expect(described_class.reader_for("/nowhere/missing.mmdb")).to be_nil
  end
end
