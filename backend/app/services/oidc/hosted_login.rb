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
        identity_providers: @project.identity_providers.enabled.order(:created_at, :id).map { |provider| IdentityProviderSummarySerializer.new(provider).serializable_hash }
      }
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
        { challenge: result.challenge, session: result.session }
      else
        { redirect_to: Authorization.new(project: @project, **client_info).complete(@interaction, result.completion) }
      end
      body[:recovery_codes] = result.recovery_codes if result.recovery_codes
      body
    end

    def realm
      @project.realm
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
