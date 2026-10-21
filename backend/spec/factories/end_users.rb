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

    trait :confidential do
      client_type { "confidential" }

      transient do
        secret { "client-secret-for-specs" }
      end

      client_secret_digest { OpenSSL::Digest::SHA256.hexdigest(secret) }
    end
  end

  factory :end_user_attribute_definition do
    project
    sequence(:key) { |n| "field_#{n}" }
    label { "Field" }
    data_type { "string" }
  end
end
