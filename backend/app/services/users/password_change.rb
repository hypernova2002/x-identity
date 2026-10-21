module Users
  # Password changes for console users and end users.
  class PasswordChange
    # @param user [User, EndUser]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(user:, ip: nil, user_agent: nil)
      @user = user
      @realm = user.realm
      @ip = ip
      @user_agent = user_agent
      @hasher = Passwords::Hasher.new
    end

    # Sets a new password after checking it against the realm's password rules.
    # @param password [String]
    # @param field [Symbol] the request field to report violations against
    # @raise [ApiError] `validation_failed`
    def set_password!(password, field: :new_password)
      violations = @realm.auth_configuration.password_violations(password)
      raise ApiError.validation(field => violations) if violations.any?
      raise ApiError.validation(field => "must be different from your current password") if @hasher.matches?(password, @user.password_digest)

      @user.change_password!(@hasher.digest(password))
    end

    # Changes the password for a signed-in user and signs out their other sessions.
    # @param current_password [String]
    # @param new_password [String]
    # @param keep_family_id [String] the refresh token family of the current session
    # @raise [ApiError] `validation_failed`
    def change!(current_password:, new_password:, keep_family_id:)
      raise ApiError.validation(current_password: "is incorrect") unless @hasher.matches?(current_password, @user.password_digest)

      set_password!(new_password)
      @user.revoke_other_sessions!(keep_family_id: keep_family_id)
      @realm.recorder(ip: @ip, user_agent: @user_agent)
        .record(action: "#{@realm.event_prefix}.password_changed", actor: @user, target: @user)
    end
  end
end
