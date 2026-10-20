require "rails_helper"

RSpec.describe HasUid do
  let(:model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "has_uid_spec_records"

      include HasUid

      self.uid_prefix = "test"

      def self.name
        "HasUidSpecRecord"
      end
    end
  end

  before do
    ActiveRecord::Base.connection.create_table(:has_uid_spec_records, temporary: true) do |t|
      t.string :uid, null: false, index: { unique: true }
    end
  end

  it "generates a prefixed uid on create" do
    expect(model_class.create!.uid).to match(/\Atest_[1-9A-HJ-NP-Za-km-z]{24}\z/)
  end

  it "keeps an explicitly assigned uid" do
    expect(model_class.create!(uid: "test_fixed").uid).to eq("test_fixed")
  end

  it "uses the uid as the URL param" do
    record = model_class.create!

    expect(record.to_param).to eq(record.uid)
  end

  it "finds records by uid" do
    record = model_class.create!

    expect(model_class.find_by_uid!(record.uid)).to eq(record)
  end

  it "raises when the prefix is missing" do
    model_class.uid_prefix = nil

    expect { model_class.create! }.to raise_error(ArgumentError, /must set uid_prefix/)
  end
end
