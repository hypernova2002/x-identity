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
      end

      get "auth-configuration", to: "auth_configurations#show"
      put "auth-configuration", to: "auth_configurations#update"

      resources :users, only: %i[index show update destroy], param: :uid
      resources :invitations, only: %i[index create destroy], param: :uid
      resources :projects, only: %i[index show create update destroy], param: :uid do
        resources :members, only: %i[index create update destroy], param: :user_uid, controller: "project_members"
      end

      # Path scopes can't be nested inside `resources` without being moved in front of the parent path,
      # so the rest of the project's routes are scoped explicitly.
      scope "projects/:project_uid", module: :projects, as: :project do
        get ".well-known/jwks.json", to: "jwks#show", format: false, as: :jwks

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
        end

        get "auth-configuration", to: "auth_configurations#show"
        put "auth-configuration", to: "auth_configurations#update"

        resources :identity_providers, path: "identity-providers", param: :uid, only: %i[index show create update destroy]
        resources :app_clients, path: "app-clients", param: :uid, only: %i[index show create update destroy] do
          post "rotate-secret", on: :member, action: :rotate_secret
        end
        resources :end_users, path: "end-users", param: :uid, only: %i[index show create update destroy] do
          member do
            delete "mfa", action: :reset_mfa
            post "sign-out", action: :sign_out
            post "invitation", action: :resend_invitation
            get "identities", action: :identities
            delete "identities/:identity_uid", action: :unlink_identity
          end
        end
        resources :attribute_definitions, path: "attributes", param: :uid, only: %i[index create update destroy]
        resources :audit_events, path: "audit-events", only: :index
      end

      resources :audit_events, path: "audit-events", only: :index
    end
  end
end
