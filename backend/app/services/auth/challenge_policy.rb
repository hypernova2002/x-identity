module Auth
  # Which challenge, if any, a user must answer next, given the factors they've proven so far (`amr`)
  # and whether passkeys work where they're signing in. The rules apply in this order:
  #
  # 1. Recovering a lost passkey after a password reset, where passwords give way to passkeys: add a new one.
  # 2. Passkeys required, and they work here: use one, or set one up.
  # 3. A second factor: the authenticator app (or a passkey instead, where one works here), or, for
  #    users with only a passkey, the passkey where MFA is required.
  # 4. An expired password: choose a new one.
  # 5. MFA required, or passkeys required where they can't work, and no authenticator app: set one up.
  class ChallengePolicy
    # @param configuration [AuthConfiguration]
    # @param relying_party [WebAuthn::RelyingParty, nil] where passkeys work for this sign-in; nil where they don't
    def initialize(configuration:, relying_party:)
      @configuration = configuration
      @relying_party = relying_party
    end

    # @param user [User, EndUser]
    # @param amr [Array<String>]
    # @return [Challenge, nil]
    def next_for(user, amr)
      passkey = passkey_here?(user)
      passkey_proven = Factors.passkey?(amr)
      mfa_proven = Factors.mfa?(amr)

      return challenge(Challenges::PASSKEY_SETUP) if recovering_passkey?(user) && !passkey_proven
      if passkeys_required_here? && !passkey_proven
        return passkey ? challenge(Challenges::PASSKEY, [ Challenges::PASSKEY ]) : challenge(Challenges::PASSKEY_SETUP)
      end
      unless @configuration.mfa_off? || mfa_proven
        return challenge(Challenges::OTP, passkey ? Challenges::MFA_METHODS : [ Challenges::OTP ]) if user.mfa_enabled?
        return challenge(Challenges::PASSKEY, [ Challenges::PASSKEY ]) if passkey && mfa_required?
      end
      return challenge(Challenges::NEW_PASSWORD) if amr.include?(Amr::PASSWORD) && user.password_expired?(@configuration)
      return challenge(Challenges::MFA_SETUP) if mfa_required? && !user.mfa_enabled? && !mfa_proven

      nil
    end

    private

    def passkey_here?(user)
      @relying_party.present? && user.webauthn_credentials.exists?(rp_id: @relying_party.id)
    end

    def recovering_passkey?(user)
      @relying_party.present? && @configuration.passwordless_after_passkey && user.recovering_passkey?
    end

    def passkeys_required_here?
      @relying_party.present? && @configuration.passkeys_required?
    end

    # Where passkeys are required but can't be used, MFA is required instead.
    def mfa_required?
      @configuration.mfa_required? || (@configuration.passkeys_required? && @relying_party.nil?)
    end

    def challenge(name, mfa_methods = [])
      Challenge.new(name: name, mfa_methods: mfa_methods)
    end
  end
end
