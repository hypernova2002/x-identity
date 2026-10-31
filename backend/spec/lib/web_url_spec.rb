require "rails_helper"

RSpec.describe WebUrl do
  it "takes https, or http on the loopback interface" do
    expect(%w[https://shop.example.com/a http://localhost:3000 http://127.0.0.1/x].map { |url| described_class.valid?(url) }).to all(be(true))
  end

  it "refuses anything else" do
    [
      nil, 42, "http://shop.example.com", "https://shop.example.com/a#b", "https:///path", "javascript:alert(1)",
      "https://shop example.com", "https://shop.example.com/#{'a' * described_class::MAX_LENGTH}"
    ].each { |url| expect(described_class.valid?(url)).to be(false), url.inspect }
  end
end
