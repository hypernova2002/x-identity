require "rails_helper"

RSpec.describe EmailAddress do
  it "trims and lowercases" do
    expect(described_class.normalize("  Dana@Acme.TEST ")).to eq("dana@acme.test")
  end

  it "treats differently composed but identical characters as equal" do
    decomposed = "José@acme.test"
    precomposed = "José@acme.test"

    expect(described_class.normalize(decomposed)).to eq(described_class.normalize(precomposed))
  end

  it "keeps dots and +tags, which can be different mailboxes" do
    expect(described_class.normalize("d.ana+shop@gmail.com")).to eq("d.ana+shop@gmail.com")
  end

  it "turns nil into an empty string" do
    expect(described_class.normalize(nil)).to eq("")
  end
end
