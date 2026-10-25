Rails.application.routes.draw do
  mount OpenapiRuby::Engine => "/api-docs" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :v1, defaults: { format: :json } do
    post "sign-up", to: "sign_ups#create"
    get "account-lookup/:slug", to: "account_lookups#show", as: :account_lookup

    scope "accounts/:account_uid", module: :accounts, as: :account do
      get "/", to: "accounts#show"
      patch "/", to: "accounts#update"

      get ".well-known/jwks.json", to: "jwks#show", format: false, as: :jwks

      scope "auth", module: :auth, as: :auth do
        post "sign-in", to: "sign_ins#create"
        post "respond-to-challenge", to: "challenges#create"
        post "mfa-setup", to: "mfa_setups#create"
        post "refresh", to: "refreshes#create"
        post "sign-out", to: "sign_outs#create"
        post "forgot-password", to: "password_resets#create"
        post "reset-password", to: "password_resets#update"
        post "resend-confirmation", to: "email_verifications#create"
        post "confirm-email", to: "email_verifications#update"
        post "confirm-email-change", to: "email_changes#update"
        post "accept-invitation", to: "invitation_acceptances#create"
      end

      get "me", to: "me#show"
      patch "me", to: "me#update"
      scope "me", module: :me, as: :me do
        put "password", to: "passwords#update"
        post "email", to: "email_changes#create"
        post "otp", to: "otps#create"
        post "otp/confirm", to: "otps#confirm"
        delete "otp", to: "otps#destroy"
        post "recovery-codes", to: "recovery_codes#create"
        get "sessions", to: "sessions#index"
        delete "sessions", to: "sessions#destroy_others"
        delete "sessions/:uid", to: "sessions#destroy", as: :session
      end

      get "auth-configuration", to: "auth_configurations#show"
      put "auth-configuration", to: "auth_configurations#update"

      resources :users, only: %i[index show update destroy], param: :uid do
        get "stats", on: :collection
      end
      resources :invitations, only: %i[index create destroy], param: :uid
      resources :deleted_projects, path: "deleted-projects", only: :index, param: :uid do
        post "restore", on: :member
      end
      resources :projects, only: %i[index show create update destroy], param: :uid do
        resources :members, only: %i[index create update destroy], param: :user_uid, controller: "project_members"
      end

      # Path scopes can't be nested inside `resources` without being moved in front of the parent path,
      # so the rest of the project's routes are scoped explicitly.
      scope "projects/:project_uid", module: :projects, as: :project do
        get ".well-known/jwks.json", to: "jwks#show", format: false, as: :jwks
        get ".well-known/openid-configuration", to: "openid_configurations#show", format: false, as: :openid_configuration

        scope "saml", as: :saml do
          get "metadata", to: "saml#metadata", format: false
          match "sso", to: "saml#sso", via: %i[get post]
          match "slo", to: "saml#slo", via: %i[get post]
          get "apps/:uid/launch", to: "saml#launch", as: :launch

          scope "sp/:provider_uid", as: :sp do
            get "metadata", to: "saml_sp#metadata", format: false
            post "acs", to: "saml_sp#acs"
            match "slo", to: "saml_sp#slo", via: %i[get post]
          end
        end

        get "portal", to: "portal#show"
        get "portal/apps", to: "portal#apps"

        scope "oauth2", module: :oauth2, as: :oauth2 do
          get "authorize", to: "authorizations#new"
          get "authorize/resume", to: "authorizations#resume", as: :authorize_resume
          post "token", to: "tokens#create"
          match "userinfo", to: "userinfo#show", via: %i[get post]
          post "revoke", to: "revocations#create"
          match "logout", to: "logouts#create", via: %i[get post]

          scope "interactions/:interaction", as: :interaction do
            get "/", to: "interactions#show"
            post "sign-in", to: "interactions#sign_in"
            post "discover", to: "interactions#discover"
            post "respond-to-challenge", to: "interactions#respond_to_challenge"
            post "mfa-setup", to: "interactions#mfa_setup"
            post "sign-up", to: "interactions#sign_up"
            post "confirm-sign-up", to: "interactions#confirm_sign_up"
            post "resend-confirmation", to: "interactions#resend_confirmation"
            post "forgot-password", to: "interactions#forgot_password"
            post "confirm-forgot-password", to: "interactions#confirm_forgot_password"
            get "providers/:uid", to: "interactions#provider", as: :provider
          end
        end

        scope "auth", module: :auth, as: :auth do
          post "sign-up", to: "sign_ups#create"
          post "confirm-sign-up", to: "confirmations#create"
          post "resend-confirmation", to: "confirmations#resend"
          post "sign-in", to: "sign_ins#create"
          post "respond-to-challenge", to: "challenges#create"
          post "mfa-setup", to: "mfa_setups#create"
          post "refresh", to: "refreshes#create"
          post "sign-out", to: "sign_outs#create"
          post "forgot-password", to: "password_resets#create"
          post "confirm-forgot-password", to: "password_resets#update"
          post "accept-invitation", to: "invitation_acceptances#create"

          get "providers", to: "providers#index"
          match "providers/callback", to: "providers#callback", via: %i[get post], as: :provider_callback
          post "providers/token", to: "providers#token", as: :provider_token
          get "providers/:uid/authorize", to: "providers#authorize", as: :provider_authorize
          post "providers/:uid/id-token", to: "providers#id_token", as: :provider_id_token
        end

        get "me", to: "me#show"
        patch "me", to: "me#update"
        scope "me", module: :me, as: :me do
          put "password", to: "passwords#update"
          post "email", to: "email_changes#create"
          post "email/confirm", to: "email_changes#confirm"
          post "otp", to: "otps#create"
          post "otp/confirm", to: "otps#confirm"
          delete "otp", to: "otps#destroy"
          post "recovery-codes", to: "recovery_codes#create"
          get "identities", to: "identities#index"
          delete "identities/:uid", to: "identities#destroy", as: :identity
          get "sessions", to: "sessions#index"
          delete "sessions", to: "sessions#destroy_others"
          delete "sessions/:uid", to: "sessions#destroy", as: :session
        end

        get "auth-configuration", to: "auth_configurations#show"
        put "auth-configuration", to: "auth_configurations#update"

        resources :identity_providers, path: "identity-providers", param: :uid, only: %i[index show create update destroy] do
          post "parse-saml-metadata", on: :collection, action: :parse_saml_metadata
        end
        resources :applications, only: :index do
          get "stats", on: :collection
        end
        resources :api_resources, path: "apis", param: :uid, only: %i[index show create update destroy]
        resources :app_clients, path: "app-clients", param: :uid, only: %i[index show create update destroy] do
          post "rotate-secret", on: :member, action: :rotate_secret
          resources :assignments, controller: "app_assignments", param: :uid, only: %i[index create destroy], defaults: { app_kind: "app_client" }
          resources :secrets, controller: "app_client_secrets", param: :uid, only: %i[index destroy]
          resources :api_grants, path: "api-grants", param: :uid, only: %i[index create update destroy]
        end
        resources :saml_apps, path: "saml-apps", param: :uid, only: %i[index show create update destroy] do
          post "parse-metadata", on: :collection, action: :parse_metadata
          resources :assignments, controller: "app_assignments", param: :uid, only: %i[index create destroy], defaults: { app_kind: "saml_app" }
        end
        resources :saml_certificates, path: "saml-certificates", param: :uid, only: %i[index create destroy] do
          post "activate", on: :member
        end
        resources :groups, param: :uid, only: %i[index show create update destroy] do
          get "stats", on: :collection
          resources :members, controller: "group_members", param: :uid, only: %i[index create destroy]
        end
        resources :end_users, path: "end-users", param: :uid, only: %i[index show create update destroy] do
          get "stats", on: :collection
          member do
            delete "mfa", action: :reset_mfa
            post "sign-out", action: :sign_out
            post "invitation", action: :resend_invitation
            get "identities", action: :identities
            get "access", action: :access
            delete "identities/:identity_uid", action: :unlink_identity
          end
          resources :sessions, controller: "end_user_sessions", param: :uid, only: %i[index destroy]
        end
        resources :attribute_definitions, path: "attributes", param: :uid, only: %i[index create update destroy]
        resources :audit_events, path: "audit-events", only: :index
      end

      resources :audit_events, path: "audit-events", only: :index
    end
  end
end
