module IdentityProviders
  # Finds the end user for a provider's verified claims, linking or creating one when needed.
  #
  # - A known `sub` signs in its linked user.
  # - Otherwise the provider must vouch for the email. A matching user is linked when their email is
  #   verified, or when they have no password yet (invited); a user with a password but an unverified
  #   email is refused, so nobody can pre-register someone else's address and take over their sign-in.
  # - With no matching user, one is created when the project allows self sign-up.
  class UserResolver
    Resolved = Data.define(:end_user, :identity)

    # @param provider [IdentityProvider]
    # @param app_client [AppClient, nil]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(provider:, app_client: nil, ip: nil, user_agent: nil)
      @provider = provider
      @project = provider.project
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
    end

    # @param claims [Hash{String => Object}] verified ID token claims
    # @param name [String, nil] a name the app collected, e.g. from Apple's first sign-in
    # @return [Resolved]
    # @raise [ApiError] `user_disabled`, `provider_email_unverified`, `email_not_verified`,
    #   `sign_up_disabled` or `identity_conflict`
    def resolve(claims, name: nil)
      attempts ||= 0
      identity = @provider.identities.includes(:end_user).find_by(subject: claims["sub"].to_s)
      return signed_in(identity, claims) if identity

      email = verified_email(claims)
      end_user = @project.end_users.find_by(email: email)
      end_user ? link(end_user, claims) : sign_up(email, claims, name)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent sign-in created the user or identity first; look again.
      attempts += 1
      retry if attempts == 1
      raise
    end

    private

    def signed_in(identity, claims)
      ensure_active!(identity.end_user)
      identity.update!(email: email_claim(claims), last_sign_in_at: Time.current)
      Resolved.new(end_user: identity.end_user, identity: identity)
    end

    def link(end_user, claims)
      ensure_active!(end_user)
      if end_user.password_set? && !end_user.email_verified?
        raise ApiError.new(:email_not_verified, message: "Confirm your email address, or sign in with your password, before signing in with #{@provider.name}.")
      end
      raise ApiError.new(:identity_conflict) if end_user.identities.exists?(identity_provider: @provider)

      identity = EndUser.transaction do
        end_user.verify_email!
        create_identity(end_user, claims)
      end
      record("end_user.identity_linked", end_user, identity)
      Resolved.new(end_user: end_user, identity: identity)
    end

    def sign_up(email, claims, name)
      raise ApiError.new(:sign_up_disabled) unless @project.allow_self_sign_up

      end_user, identity = EndUser.transaction do
        created = @project.end_users.create!(email: email, name: display_name(claims, name), email_verified_at: Time.current)
        [ created, create_identity(created, claims) ]
      end
      record("end_user.signed_up", end_user, identity)
      Resolved.new(end_user: end_user, identity: identity)
    end

    def create_identity(end_user, claims)
      end_user.identities.create!(
        identity_provider: @provider, subject: claims["sub"].to_s, email: email_claim(claims), last_sign_in_at: Time.current
      )
    end

    def ensure_active!(end_user)
      raise ApiError.new(:user_disabled, message: "This user has been disabled. Ask an administrator to re-enable it.") unless end_user.active?
    end

    def verified_email(claims)
      email = email_claim(claims)
      verified = [ true, "true" ].include?(claims["email_verified"])
      raise ApiError.new(:provider_email_unverified) unless email && verified

      email
    end

    def email_claim(claims)
      email = claims["email"]
      email.is_a?(String) && email.match?(URI::MailTo::EMAIL_REGEXP) ? EmailAddress.normalize(email) : nil
    end

    def display_name(claims, name)
      given = [ claims["given_name"], claims["family_name"] ].select { |part| part.is_a?(String) && part.present? }.join(" ")
      [ claims["name"], name, given ].find { |candidate| candidate.is_a?(String) && candidate.strip.present? }&.strip&.first(100)
    end

    def record(action, end_user, identity)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client).record(
        action: action, actor: end_user, target: end_user,
        metadata: { identity_provider: @provider.uid, provider_kind: @provider.kind, identity: identity.uid }
      )
    end
  end
end
