module Passkeys
  # Adding a passkey for a signed-in user: options for the browser, then checking what it created.
  # A passkey is a new way into the account, so both steps need a sign-in in the last {FRESH_FOR}.
  class Registration
    FRESH_FOR = 15.minutes

    # @param user [User, EndUser]
    # @param relying_party [WebAuthn::RelyingParty] see {RelyingParties}
    # @param authenticated_at [Time] when the user last signed in
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil] also names the passkey when no name is given
    def initialize(user:, relying_party:, authenticated_at:, ip: nil, user_agent: nil)
      @user = user
      @relying_party = relying_party
      @authenticated_at = authenticated_at
      @ip = ip
      @user_agent = user_agent
    end

    # @return [Hash] `registration_id`, sent back with the passkey, and `public_key`, the options for
    #   navigator.credentials.create
    # @raise [ApiError] `reauthentication_required`
    def options
      require_fresh_sign_in!
      options = @relying_party.options_for_registration(
        user: { id: @user.webauthn_id!, name: @user.email, display_name: @user.name.presence || @user.email },
        exclude: @user.webauthn_credentials.where(rp_id: @relying_party.id).pluck(:external_id),
        authenticator_selection: { resident_key: "required", require_resident_key: true, user_verification: "required" },
        attestation: "none"
      )
      _record, token = OneTimeToken.issue!(
        subject: @user, purpose: :passkey_registration, data: { "challenge" => options.challenge, "rp_id" => @relying_party.id }
      )
      { registration_id: token, public_key: options.as_json }
    end

    # @param registration_id [String] from {#options}
    # @param credential [Hash] the PublicKeyCredential the browser created, as JSON, with string or symbol keys
    # @param name [String, nil] defaults to the browser and device, e.g. "Safari on iPhone"
    # @return [WebauthnCredential]
    # @raise [ApiError] `reauthentication_required`, `invalid_passkey` or `validation_failed`
    def finish(registration_id:, credential:, name: nil)
      require_fresh_sign_in!
      credential = credential.to_h.deep_stringify_keys
      record = OneTimeToken.find_usable(registration_id, purpose: :passkey_registration)
      raise ApiError.new(:invalid_passkey) unless record && record.subject == @user && record.data["rp_id"] == @relying_party.id && record.consume!

      verified = @relying_party.verify_registration(credential, record.data["challenge"], user_verification: true)
      passkey = @user.webauthn_credentials.new(
        external_id: verified.id, public_key: verified.public_key, sign_count: verified.sign_count.to_i,
        transports: Array(credential.dig("response", "transports")), aaguid: verified.response.authenticator_data.aaguid,
        backup_eligible: verified.backup_eligible? || false, backed_up: verified.backed_up? || false,
        rp_id: @relying_party.id, name: name.presence || default_name
      )
      WebauthnCredential.transaction do
        raise ApiError.from_record(passkey) unless passkey.save

        @user.update!(passkey_recovery_until: nil) if @user.passkey_recovery_until

        @user.realm.recorder(ip: @ip, user_agent: @user_agent).record(
          action: "#{@user.realm.event_prefix}.passkey_added", actor: @user, target: @user, metadata: { passkey: passkey.uid, name: passkey.name }
        )
      end
      passkey
    rescue WebAuthn::Error
      raise ApiError.new(:invalid_passkey)
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:invalid_passkey, message: "This passkey is already saved.")
    end

    private

    def require_fresh_sign_in!
      raise ApiError.new(:reauthentication_required) if @authenticated_at < FRESH_FOR.ago
    end

    def default_name
      Devices::Describer.new.call(@user_agent).name || "Passkey"
    end
  end
end
