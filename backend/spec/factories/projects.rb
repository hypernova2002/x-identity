FactoryBot.define do
  factory :project do
    account
    sequence(:name) { |n| "Project #{n}" }
  end

  factory :project_membership do
    project
    user { association :user, account: project.account }
    role { "viewer" }
  end
end
