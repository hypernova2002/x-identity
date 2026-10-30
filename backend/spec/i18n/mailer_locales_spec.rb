require "rails_helper"

RSpec.describe "Email translations" do
  def keys(locale)
    flatten = ->(hash, prefix = nil) { hash.flat_map { |key, value| value.is_a?(Hash) ? flatten.(value, "#{prefix}#{key}.") : [ "#{prefix}#{key}" ] } }
    flatten.(YAML.load_file(Rails.root.join("config/locales/mailers.#{locale}.yml")).fetch(locale))
  end

  it "has a Japanese message for every English one, and no others" do
    expect(keys("ja")).to match_array(keys("en"))
  end
end
