FactoryBot.define do
  factory :identity_provider do
    project
    kind { "google" }
    name { "Google" }
    sequence(:client_id) { |n| "google-client-#{n}.apps.googleusercontent.com" }
    client_secret { "google-client-secret" }

    trait :oidc do
      kind { "oidc" }
      name { "Okta" }
      client_id { "okta-client" }
      client_secret { "okta-secret" }
      discovery_url { "https://idp.example.com" }
      metadata do
        {
          "issuer" => "https://idp.example.com",
          "authorization_endpoint" => "https://idp.example.com/authorize",
          "token_endpoint" => "https://idp.example.com/token",
          "jwks_uri" => "https://idp.example.com/jwks"
        }
      end
    end

    trait :saml do
      kind { "saml" }
      name { "Acme SSO" }
      client_id { nil }
      client_secret { nil }
      saml_idp_entity_id { "https://idp.acme.com/saml" }
      saml_sso_url { "https://idp.acme.com/saml/sso" }
      saml_idp_certificates { [ SamlCertificate.generate!(project: create(:project), status: "active").certificate ] }
      domains { [ "acme.com" ] }
    end

    trait :apple do
      kind { "apple" }
      name { "Apple" }
      client_id { "com.example.shop.web" }
      client_secret { nil }
      apple_team_id { "TEAM123456" }
      apple_key_id { "KEY1234567" }
      apple_private_key { OpenSSL::PKey::EC.generate("prime256v1").to_pem }
    end
  end

  factory :end_user_identity do
    end_user
    identity_provider { association :identity_provider, project: end_user.project }
    sequence(:subject) { |n| "provider-user-#{n}" }
    email { end_user.email }
  end
end
