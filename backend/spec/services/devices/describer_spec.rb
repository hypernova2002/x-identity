require "rails_helper"

RSpec.describe Devices::Describer do
  subject(:describer) { described_class.new }

  it "names desktop browsers by their operating system" do
    expect(describer.call(CHROME_ON_MAC)).to have_attributes(name: "Chrome on Mac", type: "desktop")
  end

  it "names phones by the device" do
    iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    expect(describer.call(iphone)).to have_attributes(name: "Mobile Safari on iPhone", type: "smartphone")
  end

  it "labels bots, and leaves unknown user agents unnamed" do
    expect(describer.call("Googlebot/2.1 (+http://www.google.com/bot.html)").type).to eq("bot")
    expect(describer.call(nil)).to have_attributes(name: nil, type: nil)
  end
end
