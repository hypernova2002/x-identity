module Oidc
  # What the hosted login page can do within one interaction: sign in (with any challenges), sign up,
  # confirm an email, reset a password, or go to an identity provider. The interaction stands in for
  # the app (an app client, or a SAML app), so confidential clients' secrets never reach the browser;
  # a finished sign-in never returns tokens to the page, only where to send the browser next.
  class HostedLogin
    # @param project [Project]
    # @param interaction_token [String, nil] from the hosted page's URL
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @raise [ApiError] `invalid_interaction`
    def initialize(project:, interaction_token:, ip: nil, user_agent: nil)
      @project = project
      @interaction_token = interaction_token
      @ip = ip
      @user_agent = user_agent
      @interaction = interaction_token.present? && OneTimeToken.find_usable(interaction_token, purpose: :oidc_interaction)
      @app = @interaction&.subject
      raise ApiError.new(:invalid_interaction) unless @app&.enabled? && @app.project_id == project.id

      @app_client = @app if @app.is_a?(AppClient)
    end

    # @return [Hash] what the page shows
    def details
      {
        account_name: @project.account.name,
        project_name: @project.name,
        app_name: @app.name,
        allow_self_sign_up: @project.allow_self_sign_up,
        login_hint: @interaction.data["login_hint"],
        passkeys: passkey_relying_party.present?,
        home_realm_discovery: @project.identity_providers.enabled.kind_saml.where("jsonb_array_length(domains) > 0").exists?,
        # SAML providers with domains are reached by entering an email instead of a button.
        identity_providers: @project.identity_providers.enabled.where.not(kind: "saml").or(@project.identity_providers.enabled.where(domains: []))
          .order(:created_at, :id).map { |provider| IdentityProviderSummarySerializer.new(provider).serializable_hash }
      }
    end

    # Options for signing in with a passkey instead of a password.
    # @return [Hash] see {Passkeys::Authentication#options}
    # @raise [ApiError] `passkeys_unavailable`
    def passkey_options
      passkey_authentication.options
    end

    # @param authentication_id [String]
    # @param credential [Hash] the browser's answer, as JSON
    # @return [Hash] a challenge, or where to go once signed in
    # @raise [ApiError] `passkeys_unavailable`, `invalid_passkey` or `too_many_attempts`
    def passkey_sign_in(authentication_id:, credential:)
      user, amr = passkey_authentication.verify(authentication_id: authentication_id, credential: credential)
      result_body(Auth::SignInFlow.new(realm: realm, app_client: @app_client, interaction: @interaction, **client_info).continue(user: user, amr: amr, authenticated_at: Time.current))
    end

    # Options for answering a second-factor challenge with a passkey.
    # @param session [String]
    # @return [Hash]
    def passkey_challenge_options(session:)
      challenge_response.passkey_options(session: session)
    end

    # Home realm discovery: the SAML provider for the email's domain, which the page sends the user to
    # instead of asking for a password. Domains aren't listed on the page, so it can't reveal which
    # companies use the project.
    # @param email [String]
    # @return [IdentityProvider, nil]
    def discover(email:)
      domain = email.split("@", 2).last.to_s.downcase
      return nil if domain.blank? || !email.include?("@")

      @project.identity_providers.enabled.kind_saml.where("domains @> ?", [ domain ].to_json).first
    end

    # @return [Hash] a challenge, or where to go once signed in
    def sign_in(email:, password:)
      result_body(Auth::SignIn.new(realm: realm, app_client: @app_client, interaction: @interaction, **client_info).call(email: email, password: password))
    end

    # @return [Hash] a challenge, or where to go once signed in
    def respond_to_challenge(**answer)
      result_body(challenge_response.call(**answer))
    end

    # @param session [String]
    # @return [Mfa::Enrollment]
    def start_mfa_setup(session:)
      challenge_response.start_mfa_setup(session: session)
    end

    def sign_up(**input)
      EndUsers::SignUp.new(project: @project, app_client: @app_client, **client_info).call(**input)
    end

    def confirm_sign_up(email:, code:)
      confirmation.confirm(email: email, code: code)
    end

    def resend_confirmation(email:)
      confirmation.resend(email: email)
    end

    def forgot_password(email:)
      password_reset.request(email: email)
    end

    def confirm_forgot_password(email:, code:, password:)
      password_reset.confirm(email: email, code: code, password: password)
    end

    # @param provider_uid [String]
    # @return [String] the provider URL
    # @raise [ActiveRecord::RecordNotFound]
    def provider_url(provider_uid)
      provider = @project.identity_providers.enabled.find_by_uid!(provider_uid)
      IdentityProviders::BrowserSignIn.new(project: @project, **client_info)
        .authorize_for_interaction(provider: provider, interaction: @interaction, interaction_token: @interaction_token)
    end

    private

    def result_body(result)
      body = if result.challenged?
        { challenge: result.challenge, session: result.session, mfa_methods: result.mfa_methods }.compact
      else
        { redirect_to: Authorization.new(project: @project, **client_info).complete(@interaction, result.completion) }
      end
      body[:recovery_codes] = result.recovery_codes if result.recovery_codes
      body
    end

    def realm
      @project.realm
    end

    # Passkeys belong to the custom domain the interaction started on.
    def passkey_relying_party
      @passkey_relying_party ||= Passkeys::RelyingParties.for_realm(realm, endpoints: ProjectEndpoints.for_issuer(@project, @interaction.data["issuer"]))
    rescue ApiError
      nil
    end

    def passkey_authentication
      raise ApiError.new(:passkeys_unavailable) unless passkey_relying_party

      Passkeys::Authentication.new(realm: realm, relying_party: passkey_relying_party)
    end

    def challenge_response
      Auth::ChallengeResponse.new(realm: realm, app_client: @app_client, interaction: @interaction, **client_info)
    end

    def confirmation
      EndUsers::Confirmation.new(project: @project, app_client: @app_client, **client_info)
    end

    def password_reset
      EndUsers::PasswordReset.new(project: @project, app_client: @app_client, **client_info)
    end

    def client_info
      { ip: @ip, user_agent: @user_agent }
    end
  end
end
