FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    sequence(:slug) { |n| "account-#{n}" }

    after(:create) { |account| account.auth_configuration! }
  end
end
