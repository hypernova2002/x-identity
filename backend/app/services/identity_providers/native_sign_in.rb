module IdentityProviders
  # Sign-in for native apps that use a provider's SDK (Sign in with Apple, Google Sign-In) and send
  # the ID token it returns, with the nonce the app generated for that sign-in.
  class NativeSignIn
    # @param provider [IdentityProvider]
    # @param app_client [AppClient]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param key_set [KeySet]
    # @param issuer [String, nil] the custom domain's issuer when the request arrived on one
    def initialize(provider:, app_client:, ip: nil, user_agent: nil, key_set: KeySet.new, issuer: nil)
      @provider = provider
      @app_client = app_client
      @issuer = issuer
      @ip = ip
      @user_agent = user_agent
      @key_set = key_set
    end

    # @param id_token [String]
    # @param nonce [String]
    # @param name [String, nil] e.g. the name Apple gives the app on the first sign-in only
    # @return [Auth::SignInResult]
    # @raise [ApiError] `invalid_id_token`, or any {UserResolver#resolve} error
    def call(id_token:, nonce:, name: nil)
      claims = IdTokenVerifier.new(provider: @provider, key_set: @key_set).verify(id_token, nonce: nonce)
      end_user = UserResolver.new(provider: @provider, app_client: @app_client, ip: @ip, user_agent: @user_agent)
        .resolve(claims, name: name).end_user

      Auth::SignInFlow.new(context: Auth::SignInContext.new(realm: @provider.project.realm(issuer: @issuer), app_client: @app_client, ip: @ip, user_agent: @user_agent))
        .continue(user: end_user, amr: [ Auth::Amr::FEDERATED ], authenticated_at: Time.current)
    end
  end
end
