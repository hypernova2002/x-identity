module Projects
  # Creating and deleting projects are account-level events; changes to a project's own settings
  # go to the project's audit log.
  class Management
    SETTINGS = %i[name allow_self_sign_up confirm_sign_up_url reset_password_url accept_invitation_url].freeze

    # @param actor [User]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, ip: nil, user_agent: nil)
      @actor = actor
      @account = actor.account
      @ip = ip
      @user_agent = user_agent
    end

    # @param name [String]
    # @return [Project]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(name:)
      raise ApiError.new(:forbidden) unless AccountPolicy.new(@actor).manage?

      project = @account.projects.new(name: name)
      Project.transaction do
        raise ApiError.from_record(project) unless project.save

        project.auth_configuration!
      end

      @account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "project.created", actor: @actor, target: project)
      project
    end

    # @param project [Project]
    # @param attributes [Hash] any of {SETTINGS}
    # @return [Project]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def update(project, **attributes)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).update?

      project.assign_attributes(attributes.slice(*SETTINGS))
      changes = project.changes.transform_values { |from, to| { from: from, to: to } }
      raise ApiError.from_record(project) unless project.save

      if changes.any?
        project.realm.recorder(ip: @ip, user_agent: @user_agent)
          .record(action: "project.updated", actor: @actor, target: project, metadata: { changes: changes })
      end
      project
    end

    # Deletes the project with its end users, app clients, attributes and keys. Its audit events are kept.
    # @param project [Project]
    # @raise [ApiError] `forbidden`
    def destroy(project)
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, project).destroy?

      Project.transaction do
        end_user_ids = project.end_users.select(:id)
        [ RefreshToken, OneTimeToken, RecoveryCode, OtpCredential ].each do |model|
          model.where(subject_type: "EndUser", subject_id: end_user_ids).delete_all
        end
        EndUserIdentity.where(end_user_id: end_user_ids).delete_all
        OneTimeToken.where(subject_type: "BrowserSession", subject_id: BrowserSession.where(project: project).select(:id)).delete_all
        BrowserSessionApp.where(browser_session_id: BrowserSession.where(project: project).select(:id)).delete_all
        BrowserSession.where(project: project).delete_all
        GroupMembership.where(group_id: project.groups.select(:id)).delete_all
        project.app_assignments.delete_all
        project.groups.delete_all
        OneTimeToken.where(subject_type: "SamlApp", subject_id: project.saml_apps.select(:id)).delete_all
        project.saml_apps.delete_all
        project.saml_certificates.delete_all
        OneTimeToken.where(subject_type: "AppClient", subject_id: project.app_clients.select(:id)).delete_all
        OneTimeToken.where(subject_type: "IdentityProvider", subject_id: project.identity_providers.select(:id)).delete_all
        IdentityProviderGroupMapping.where(identity_provider_id: project.identity_providers.select(:id)).delete_all
        ConsumedSamlAssertion.where(identity_provider_id: project.identity_providers.select(:id)).delete_all
        project.identity_providers.delete_all
        project.end_users.delete_all
        project.app_clients.delete_all
        project.end_user_attribute_definitions.delete_all
        project.signing_keys.delete_all
        project.auth_configuration&.delete
        project.destroy!
      end

      @account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "project.deleted", actor: @actor, target: project)
    end
  end
end
