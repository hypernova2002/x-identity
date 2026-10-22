FactoryBot.define do
  factory :project do
    account
    sequence(:name) { |n| "Project #{n}" }
  end

  factory :group do
    project
    sequence(:name) { |n| "Group #{n}" }
  end

  factory :project_membership do
    project
    user { association :user, account: project.account }
    role { "viewer" }
  end
end

FactoryBot.define do
  factory :saml_app do
    project
    sequence(:name) { |n| "SAML app #{n}" }
    sequence(:entity_id) { |n| "https://sp#{n}.example.com/saml/metadata" }
    acs_urls { [ "#{entity_id.delete_suffix('/saml/metadata')}/saml/acs" ] }
    attribute_mappings { [ { "name" => "email", "source" => "email" }, { "name" => "groups", "source" => "groups" } ] }

    trait :with_slo do
      slo_url { "#{entity_id.delete_suffix('/saml/metadata')}/saml/slo" }
    end

    transient do
      assigned_to_everyone { true }
    end

    after(:create) do |app, evaluator|
      next unless evaluator.assigned_to_everyone

      group = app.project.groups.find_or_create_by!(name: "All end users") { |created| created.default_for_new_users = true }
      AppAssignment.create!(project: app.project, app: app, principal: group)
    end
  end
end
