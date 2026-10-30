module EndUsers
  # Self-service sign-up. The request is validated and the password hashed right away, but whether
  # the email already exists is decided in a background job, so the response is the same either way:
  # a new address gets a confirmation code, an unconfirmed one gets a fresh code, and a confirmed one
  # gets an "you already have an account" email. Existing users are never changed.
  class SignUp
    # @param project [Project]
    # @param app_client [AppClient]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, app_client: nil, ip: nil, user_agent: nil)
      @project = project
      @app_client = app_client
      @ip = ip
      @user_agent = user_agent
    end

    # @param email [String]
    # @param password [String]
    # @param name [String, nil]
    # @param custom_attributes [Hash]
    # @raise [ApiError] `sign_up_disabled` or `validation_failed`
    def call(email:, password:, name: nil, custom_attributes: {})
      raise ApiError.new(:sign_up_disabled) unless @project.allow_self_sign_up

      result = AttributeValidator.new(project: @project).validate(custom_attributes)
      details = result.details
      details += @project.auth_configuration!.password_violations(password).map { |message| { field: "password", message: message } }
      raise ApiError.new(:validation_failed, details: details) if details.any?

      EndUserSignUpJob.perform_later(
        project_id: @project.id,
        app_client_id: @app_client&.id,
        email: email,
        name: name,
        password_digest: Passwords::Hasher.new.digest(password),
        custom_attributes: result.values,
        ip: @ip,
        user_agent: @user_agent
      )
    end

    # Creates the user or notifies the existing one. Run by {EndUserSignUpJob}.
    # @param email [String]
    # @param name [String, nil]
    # @param password_digest [String]
    # @param custom_attributes [Hash]
    def deliver(email:, name:, password_digest:, custom_attributes:)
      end_user = @project.end_users.find_by(email: email)
      return notify_existing(end_user) if end_user

      end_user = EndUser.transaction do
        @project.end_users.create!(
          email: email,
          name: name,
          password_digest: password_digest,
          password_changed_at: Time.current,
          custom_attributes: custom_attributes
        ).tap { |created| recorder.record(action: "end_user.signed_up", actor: created, target: created) }
      end
      Emails.new(project: @project).send_confirmation(end_user)
    rescue ActiveRecord::RecordNotUnique
      notify_existing(@project.end_users.find_by!(email: email))
    end

    private

    def notify_existing(end_user)
      recorder.record(action: "end_user.sign_up_repeated", target: end_user, metadata: { email_verified: end_user.email_verified? })
      return if end_user.disabled?

      emails = Emails.new(project: @project)
      end_user.email_verified? ? emails.send_existing_account_notice(end_user) : emails.send_confirmation(end_user)
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: @app_client)
    end
  end
end
