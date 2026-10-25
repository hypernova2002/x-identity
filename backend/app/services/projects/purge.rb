module Projects
  # Permanently deletes a deleted project's data, in batches of {BATCH} rows, each committed on its
  # own, so it never holds a long transaction or long locks. Safe to run again after an interruption:
  # every step deletes whatever is left. Audit events are kept.
  class Purge
    BATCH = 1_000

    # @param project [Project] a deleted project
    def initialize(project)
      @project = project
    end

    def call
      steps.each { |scope| delete_in_batches(scope) }
      @project.auth_configuration&.delete
      @project.delete
      @project.account.realm.recorder.record(action: "project.purged", target: @project, metadata: { name: @project.name })
    end

    private

    # Leaves first, so nothing points at a row that's already gone.
    def steps
      end_users = @project.end_users.select(:id)
      browser_sessions = BrowserSession.where(project_id: @project.id).select(:id)
      providers = @project.identity_providers.select(:id)
      [
        *[ RefreshToken, OneTimeToken, RecoveryCode, OtpCredential ].map { |model| model.where(subject_type: "EndUser", subject_id: end_users) },
        EndUserIdentity.where(end_user_id: end_users),
        DeviceSession.where(project_id: @project.id),
        OneTimeToken.where(subject_type: "BrowserSession", subject_id: browser_sessions),
        BrowserSessionApp.where(browser_session_id: browser_sessions),
        BrowserSession.where(project_id: @project.id),
        GroupMembership.where(group_id: @project.groups.select(:id)),
        @project.app_assignments,
        IdentityProviderGroupMapping.where(identity_provider_id: providers),
        @project.groups,
        OneTimeToken.where(subject_type: "SamlApp", subject_id: @project.saml_apps.select(:id)),
        @project.saml_apps,
        @project.saml_certificates,
        OneTimeToken.where(subject_type: "AppClient", subject_id: @project.app_clients.select(:id)),
        OneTimeToken.where(subject_type: "IdentityProvider", subject_id: providers),
        ConsumedSamlAssertion.where(identity_provider_id: providers),
        @project.identity_providers,
        @project.end_users,
        AppClientSecret.where(app_client_id: @project.app_clients.select(:id)),
        ApiGrant.where(app_client_id: @project.app_clients.select(:id)),
        @project.app_clients,
        @project.api_resources,
        @project.end_user_attribute_definitions,
        @project.signing_keys,
        @project.domains,
        @project.project_memberships
      ]
    end

    def delete_in_batches(scope)
      loop { break if scope.limit(BATCH).delete_all.zero? }
    end
  end
end
