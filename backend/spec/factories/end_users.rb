FactoryBot.define do
  factory :end_user do
    project
    sequence(:email) { |n| "customer#{n}@shop.test" }
    name { "Casey Customer" }
    password_changed_at { Time.current }
    email_verified_at { Time.current }

    transient do
      password { "correct horse battery staple" }
    end

    password_digest { Passwords::Hasher.new.digest(password) }

    # Like the migration that introduced app assignment, everyone is in the project's
    # "All end users" group, which every app client is assigned to.
    transient do
      in_all_end_users_group { true }
    end

    after(:create) do |end_user, evaluator|
      next unless evaluator.in_all_end_users_group

      group = end_user.project.groups.find_or_create_by!(name: "All end users") { |created| created.default_for_new_users = true }
      group.group_memberships.find_or_create_by!(end_user: end_user)
    end

    trait :unverified do
      email_verified_at { nil }
    end

    trait :invited do
      password_digest { nil }
      password_changed_at { nil }
      email_verified_at { nil }
    end

    trait :with_mfa do
      after(:create) do |end_user|
        OtpCredential.generate(subject: end_user).tap { |credential| credential.confirmed_at = Time.current }.save!
        end_user.association(:otp_credential).reset
      end
    end
  end

  factory :app_client do
    project
    sequence(:name) { |n| "App #{n}" }
    client_type { "public" }
    allowed_origins { [] }

    transient do
      assigned_to_everyone { true }
    end

    after(:create) do |app_client, evaluator|
      next unless evaluator.assigned_to_everyone

      group = app_client.project.groups.find_or_create_by!(name: "All end users") { |created| created.default_for_new_users = true }
      AppAssignment.create!(project: app_client.project, app: app_client, principal: group)
    end

    trait :confidential do
      client_type { "confidential" }

      transient do
        secret { "client-secret-for-specs" }
      end

      after(:create) do |app_client, evaluator|
        app_client.secrets.create!(digest: AppClientSecret.digest(evaluator.secret), last_four: evaluator.secret.last(4))
      end
    end

    trait :machine do
      confidential
      machine { true }
      redirect_uris { [] }
      assigned_to_everyone { false }
    end
  end

  factory :end_user_attribute_definition do
    project
    sequence(:key) { |n| "field_#{n}" }
    label { "Field" }
    data_type { "string" }
  end
end
