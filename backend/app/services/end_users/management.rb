module EndUsers
  # Changes console users make to a project's end users.
  class Management
    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, project:, ip: nil, user_agent: nil)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # Creates an end user without a password and, by default, emails them an invitation to set one.
    # @param email [String]
    # @param name [String, nil]
    # @param custom_attributes [Hash]
    # @param send_invitation [Boolean]
    # @return [EndUser]
    # @raise [ApiError] `forbidden`, `email_taken` or `validation_failed`
    def create(email:, name: nil, custom_attributes: {}, send_invitation: true)
      authorize!
      raise ApiError.new(:email_taken, message: "An end user with this email address already exists in this project.") if @project.end_users.exists?(email: email)

      result = AttributeValidator.new(project: @project).validate(custom_attributes, by_admin: true)
      raise ApiError.new(:validation_failed, details: result.details) if result.details.any?

      end_user = @project.end_users.new(email: email, name: name, custom_attributes: result.values)
      EndUser.transaction do
        raise ApiError.from_record(end_user) unless end_user.save

        recorder.record(action: "end_user.created", actor: @actor, target: end_user, metadata: { invited: send_invitation })
      end

      EndUserEmailJob.perform_later(kind: "invitation", end_user_id: end_user.id) if send_invitation
      end_user
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:email_taken, message: "An end user with this email address already exists in this project.")
    end

    # @param end_user [EndUser]
    # @param name [String, nil]
    # @param custom_attributes [Hash, nil] values to set; `nil` values clear an attribute
    # @param status [String, nil] "active" or "disabled"
    # @return [EndUser]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def update(end_user, **changes)
      authorize!

      previous_status = nil
      EndUser.transaction do
        end_user.lock!
        previous_status = end_user.status
        if changes.key?(:custom_attributes)
          result = AttributeValidator.new(project: @project).validate(changes[:custom_attributes], existing: end_user.custom_attributes, by_admin: true)
          raise ApiError.new(:validation_failed, details: result.details) if result.details.any?

          end_user.custom_attributes = result.values
        end
        end_user.name = changes[:name] if changes.key?(:name)
        raise ApiError.from_record(end_user) unless end_user.save

        end_user.disable! if changes[:status] == "disabled" && end_user.active?
        end_user.enable! if changes[:status] == "active" && end_user.disabled?
        record_update(end_user, changes, previous_status)
      end

      end_user
    end

    # @param end_user [EndUser]
    def destroy(end_user)
      authorize!
      EndUser.transaction do
        end_user.destroy!
        recorder.record(action: "end_user.deleted", actor: @actor, target: end_user)
      end
    end

    # Turns off the end user's MFA, e.g. after they lose their phone.
    # @param end_user [EndUser]
    def reset_mfa(end_user)
      authorize!
      EndUser.transaction do
        end_user.remove_mfa!
        recorder.record(action: "end_user.mfa_reset", actor: @actor, target: end_user)
      end
    end

    # @param end_user [EndUser]
    # @param passkey [WebauthnCredential] one of the end user's
    def remove_passkey(end_user, passkey)
      authorize!
      WebauthnCredential.transaction do
        passkey.destroy!
        recorder.record(action: "end_user.passkey_removed", actor: @actor, target: end_user, metadata: { passkey: passkey.uid, name: passkey.name })
      end
    end

    # @param end_user [EndUser]
    # @param identity [EndUserIdentity] one of the end user's
    # @raise [ApiError] `forbidden` or `last_sign_in_method`
    def unlink_identity(end_user, identity)
      authorize!
      Identities.new(end_user: end_user, actor: @actor, ip: @ip, user_agent: @user_agent).unlink(identity)
    end

    # @param device_session [DeviceSession] one of an end user's
    # @raise [ApiError] `forbidden`
    def sign_out_device(device_session)
      authorize!
      DeviceSessions::Management.new(actor: @actor, realm: @project.realm, ip: @ip, user_agent: @user_agent).sign_out(device_session)
    end

    # @param end_user [EndUser]
    def sign_out_everywhere(end_user)
      authorize!
      EndUser.transaction do
        end_user.revoke_all_sessions!
        recorder.record(action: "end_user.signed_out_everywhere", actor: @actor, target: end_user)
      end
    end

    # @param end_user [EndUser]
    # @raise [ApiError] `conflict` when the end user has already set a password
    def resend_invitation(end_user)
      authorize!
      raise ApiError.new(:conflict, message: "This end user has already accepted their invitation.") if end_user.password_set?

      EndUserEmailJob.perform_later(kind: "invitation", end_user_id: end_user.id)
      recorder.record(action: "end_user.invitation_resent", actor: @actor, target: end_user)
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_end_users?
    end

    def record_update(end_user, changes, previous_status)
      fields = (changes.keys & %i[name custom_attributes]).map(&:to_s)
      recorder.record(action: "end_user.updated", actor: @actor, target: end_user, metadata: { fields: fields }) if fields.any?
      return if end_user.status == previous_status

      recorder.record(action: end_user.disabled? ? "end_user.disabled" : "end_user.enabled", actor: @actor, target: end_user)
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
