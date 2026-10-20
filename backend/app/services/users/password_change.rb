module Users
  class PasswordChange
    # @param user [User]
    def initialize(user:)
      @user = user
      @hasher = Passwords::Hasher.new
    end

    # Sets a new password after checking it against the account's password rules.
    # @param password [String]
    # @param field [Symbol] the request field to report violations against
    # @raise [ApiError] `validation_failed`
    def set_password!(password, field: :new_password)
      violations = @user.account.auth_configuration!.password_violations(password)
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
      AuditEvents::Recorder.new(account: @user.account).record(action: "user.password_changed", actor: @user, target: @user)
    end
  end
end
