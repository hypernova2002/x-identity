module DeviceSessions
  # Signing devices out, by the user themselves or by an admin, with an audit trail.
  class Management
    # @param actor [User, EndUser] who is signing the device out
    # @param realm [Realms::AccountRealm, Realms::ProjectRealm] the realm of the device's user
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, realm:, ip: nil, user_agent: nil)
      @actor = actor
      @realm = realm
      @ip = ip
      @user_agent = user_agent
    end

    # @param device_session [DeviceSession]
    def sign_out(device_session)
      device_session.revoke!
      record("device_signed_out", device_session.subject, device: device_session.uid, device_name: device_session.device_name)
    end

    # Signs out every device of `user` except the one the current access token belongs to.
    # @param user [User, EndUser]
    # @param keep_session_id [String] the current access token's `sid`
    def sign_out_others(user, keep_session_id:)
      user.revoke_other_sessions!(keep_session_id: keep_session_id)
      record("other_devices_signed_out", user)
    end

    private

    def record(action, user, **metadata)
      @realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "#{@realm.event_prefix}.#{action}", actor: @actor, target: user, metadata: metadata)
    end
  end
end
