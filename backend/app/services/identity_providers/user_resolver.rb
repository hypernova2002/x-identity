module IdentityProviders
  # Finds the end user for a provider's verified claims, linking or creating one when needed.
  #
  # - A known `sub` signs in its linked user.
  # - Otherwise the provider must vouch for the email. A matching user is linked when their email is
  #   verified, or when they have no password yet (invited); a user with a password but an unverified
  #   email is refused, so nobody can pre-register someone else's address and take over their sign-in.
  # - With no matching user, one is created when the project allows self sign-up, or the provider
  #   creates users on first sign-in.
  # - Providers with group mappings set the user's memberships of the mapped groups at every sign-in.
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
      resolved = if identity
        signed_in(identity, claims)
      else
        email = verified_email(claims)
        end_user = @project.end_users.find_by(email: email)
        end_user ? link(end_user, claims) : sign_up(email, claims, name)
      end
      sync_groups(resolved.end_user, claims["groups"]) if claims.key?("groups")
      resolved
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
        create_identity(end_user, claims).tap { |created| record("end_user.identity_linked", end_user, created) }
      end
      Resolved.new(end_user: end_user, identity: identity)
    end

    def sign_up(email, claims, name)
      raise ApiError.new(:sign_up_disabled) unless @project.allow_self_sign_up || @provider.create_users

      end_user, identity = EndUser.transaction do
        created = @project.end_users.create!(email: email, name: display_name(claims, name), email_verified_at: Time.current)
        linked = create_identity(created, claims)
        record("end_user.signed_up", created, linked)
        [ created, linked ]
      end
      Resolved.new(end_user: end_user, identity: identity)
    end

    # Only the mapped groups follow the provider; the user's other groups are left alone.
    def sync_groups(end_user, values)
      mappings = @provider.group_mappings.includes(:group).to_a
      return if mappings.empty?

      wanted = mappings.select { |mapping| Array(values).include?(mapping.value) }.map(&:group).uniq
      mapped = mappings.map(&:group).uniq
      current = end_user.groups.where(id: mapped.map(&:id)).to_a

      changes = { added: (wanted - current).map(&:name), removed: (current - wanted).map(&:name) }
      GroupMembership.transaction do
        (wanted - current).each { |group| group.group_memberships.create!(end_user: end_user) }
        (current - wanted).each { |group| group.group_memberships.where(end_user: end_user).delete_all }
        record_groups(end_user, changes) if changes.values.any?(&:present?)
      end
    end

    def record_groups(end_user, changes)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client).record(
        action: "end_user.groups_synced", actor: end_user, target: end_user, metadata: changes.merge(identity_provider: @provider.uid)
      )
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
      if @provider.kind_saml? && !(email && verified)
        raise ApiError.new(:provider_email_unverified, message: "#{@provider.name} can only sign in addresses at #{@provider.domains.join(', ').presence || 'its listed domains'}.")
      end
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
