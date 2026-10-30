module Passkeys
  # A user's own passkeys: listing, renaming and removing them.
  class Management
    # @param user [User, EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(user:, ip: nil, user_agent: nil)
      @user = user
      @ip = ip
      @user_agent = user_agent
    end

    # @return [ActiveRecord::Relation<WebauthnCredential>]
    def list
      @user.webauthn_credentials.order(:created_at, :id)
    end

    # @param uid [String]
    # @return [WebauthnCredential]
    # @raise [ActiveRecord::RecordNotFound]
    def find(uid)
      @user.webauthn_credentials.find_by_uid!(uid)
    end

    # @param passkey [WebauthnCredential]
    # @param name [String]
    # @return [WebauthnCredential]
    # @raise [ApiError] `validation_failed`
    def rename(passkey, name:)
      previous = passkey.name
      WebauthnCredential.transaction do
        raise ApiError.from_record(passkey) unless passkey.update(name: name)

        record("passkey_renamed", passkey, from: previous)
      end
      passkey
    end

    # @param passkey [WebauthnCredential]
    def remove(passkey)
      WebauthnCredential.transaction do
        passkey.destroy!
        record("passkey_removed", passkey)
      end
    end

    private

    def record(event, passkey, **metadata)
      @user.realm.recorder(ip: @ip, user_agent: @user_agent).record(
        action: "#{@user.realm.event_prefix}.#{event}", actor: @user, target: @user, metadata: { passkey: passkey.uid, name: passkey.name, **metadata }
      )
    end
  end
end
