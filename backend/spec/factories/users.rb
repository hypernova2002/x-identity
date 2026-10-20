FactoryBot.define do
  factory :user do
    account
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { "member" }
    password_changed_at { Time.current }
    email_verified_at { Time.current }

    transient do
      password { "correct horse battery staple" }
    end

    password_digest { Passwords::Hasher.new.digest(password) }

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :unverified do
      email_verified_at { nil }
    end

    trait :disabled do
      status { "disabled" }
    end

    trait :with_mfa do
      after(:create) do |user|
        OtpCredential.generate(subject: user).tap { |credential| credential.confirmed_at = Time.current }.save!
        user.association(:otp_credential).reset
      end
    end
  end
end
