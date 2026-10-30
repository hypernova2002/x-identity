require "rails_helper"

module RequestFieldExamplesSpec
  T = JsonModel::Types

  class ExampleRequest < ApplicationRequestModel
    attribute :name, T::String.constrained(min_size: 1, max_size: 10)
    attribute? :nickname, T::String.constrained(max_size: 5).optional
    attribute :email, RequestTypes::Email
    attribute? :role, T::String.enum("admin", "member")
    attribute? :enabled, T::Bool
    attribute? :limit, T::Integer.constrained(gteq: 1, lteq: 60)
    attribute? :urls, T::Array.of(T::String.constrained(min_size: 1, max_size: 8)).constrained(min_size: 1, max_size: 3)
    attribute? :extra, T::Hash.constrained(max_size: 3)
  end
end

RSpec.describe RequestFieldExamplesSpec::ExampleRequest do
  let(:valid_body) { { name: "Dana", email: "dana@acme.test" } }

  it_behaves_like "a required field", :name
  it_behaves_like "a string field", :name, min: 1, max: 10
  it_behaves_like "an optional field", :nickname
  it_behaves_like "a string field", :nickname, max: 5, nullable: true
  it_behaves_like "an email field", :email
  it_behaves_like "an enum field", :role, values: %w[admin member]
  it_behaves_like "a boolean field", :enabled
  it_behaves_like "an integer field", :limit, min: 1, max: 60
  it_behaves_like "an array field", :urls, min: 1, max: 3, item: "https", item_max: 8, invalid_items: [ "" ]
  it_behaves_like "a hash field", :extra, max: 3
end
