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
        post "totp", to: "totps#create"
        post "totp/confirm", to: "totps#confirm"
        delete "totp", to: "totps#destroy"
        post "recovery-codes", to: "recovery_codes#create"
      end

      get "auth-configuration", to: "auth_configurations#show"
      put "auth-configuration", to: "auth_configurations#update"

      resources :users, only: %i[index show update destroy], param: :uid
      resources :invitations, only: %i[index create destroy], param: :uid
      resources :projects, only: %i[index show create update destroy], param: :uid do
        resources :members, only: %i[index create update destroy], param: :user_uid, controller: "project_members"
      end
      resources :audit_events, path: "audit-events", only: :index
    end
  end
end
