require "rails_helper"

RSpec.describe Me::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :name
  it_behaves_like "a name field", :name

  it_behaves_like "an optional field", :locale
  it_behaves_like "an enum field", :locale, values: HasLocale::LOCALES, nullable: true
end
