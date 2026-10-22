module Apps
  # Whether an end user may sign in to an app. Apps need an assignment, to the user or one of their
  # groups; the app portal is open to everyone, since it only lists the apps they're assigned.
  module Access
    module_function

    # @param app [AppClient, SamlApp]
    # @param end_user [EndUser]
    # @return [Boolean]
    def allowed?(app, end_user)
      (app.is_a?(AppClient) && app.portal?) || AppAssignment.grants?(app, end_user)
    end

    # @param app [AppClient, SamlApp]
    # @param end_user [EndUser]
    # @param recorder [AuditEvents::Recorder]
    # @raise [ApiError] `app_access_denied`, after recording the refusal
    def authorize!(app, end_user, recorder:)
      return if allowed?(app, end_user)

      recorder.record(action: "end_user.app_access_denied", actor: end_user, target: end_user, metadata: { app: app.uid, app_name: app.name })
      raise ApiError.new(:app_access_denied)
    end
  end
end
