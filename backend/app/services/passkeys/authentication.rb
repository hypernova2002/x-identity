module Passkeys
  # Signing in with a passkey: options for the browser, then checking the signed answer. Without a
  # user, any passkey for the domain can answer (they're discoverable, so the browser offers the
  # user's own); as a second factor, only the user's own passkeys can.
  class Authentication
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm] whose users can sign in
    # @param relying_party [WebAuthn::RelyingParty] see {RelyingParties}
    def initialize(realm:, relying_party:)
      @realm = realm
      @relying_party = relying_party
      @configuration = realm.auth_configuration
    end

    # @param user [User, EndUser, nil] for a second factor
    # @return [Hash] `authentication_id`, sent back with the answer, and `public_key`, the options
    #   for navigator.credentials.get
    def options(user: nil)
      allowed = user ? user.webauthn_credentials.where(rp_id: @relying_party.id).pluck(:external_id) : []
      options = @relying_party.options_for_authentication(allow: allowed, user_verification: "required")
      _record, token = OneTimeToken.issue!(
        subject: user || @realm.owner, purpose: :passkey_authentication, replace: false,
        data: { "challenge" => options.challenge, "rp_id" => @relying_party.id }
      )
      { authentication_id: token, public_key: options.as_json }
    end

    # @param authentication_id [String] from {#options}
    # @param credential [Hash] the browser's answer (a PublicKeyCredential), as JSON
    # @param user [User, EndUser, nil] for a second factor: the passkey must be theirs
    # @return [Array(User, Array<String>), Array(EndUser, Array<String>)] the user, and the `amr` the passkey proves
    # @raise [ApiError] `invalid_passkey` or `too_many_attempts`
    def verify(authentication_id:, credential:, user: nil)
      record = OneTimeToken.find_usable(authentication_id.to_s, purpose: :passkey_authentication)
      raise ApiError.new(:invalid_passkey) unless record && record.subject == (user || @realm.owner) && record.data["rp_id"] == @relying_party.id && record.consume!

      passkey = WebauthnCredential.find_by(external_id: credential["id"].to_s, rp_id: @relying_party.id)
      owner = passkey&.subject
      raise ApiError.new(:invalid_passkey) unless owner && @realm.owns?(owner) && (user.nil? || owner == user)

      lockout = Auth::Lockout.new(owner: @realm.owner, configuration: @configuration)
      raise ApiError.new(:too_many_attempts) if lockout.locked?(owner.email)

      begin
        handle = credential.dig("response", "userHandle")
        raise WebAuthn::Error, "the passkey belongs to someone else" if handle.present? && handle != owner.webauthn_id

        verified = @relying_party.verify_authentication(
          credential, record.data["challenge"], public_key: passkey.public_key, sign_count: passkey.sign_count, user_verification: true
        )
      rescue WebAuthn::Error
        lockout.register_failure(owner.email)
        raise ApiError.new(:invalid_passkey)
      end
      raise ApiError.new(:invalid_passkey) unless owner.active?

      lockout.reset(owner.email)
      passkey.update!(sign_count: verified.sign_count.to_i, last_used_at: Time.current)
      [ owner, passkey.amr ]
    end
  end
end
