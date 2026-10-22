module AppClients
  class Management
    Created = Data.define(:app_client, :client_secret)

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

    # @param name [String]
    # @param client_type [String] "public" or "confidential"
    # @param allowed_origins [Array<String>]
    # @param redirect_uris [Array<String>]
    # @param post_logout_redirect_uris [Array<String>]
    # @param launch_url [String, nil]
    # @return [Created] the client, and its secret for confidential clients (shown once)
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(name:, client_type:, allowed_origins: [], redirect_uris: [], post_logout_redirect_uris: [], launch_url: nil)
      authorize!
      app_client = @project.app_clients.new(
        name: name, client_type: client_type, allowed_origins: allowed_origins,
        redirect_uris: redirect_uris, post_logout_redirect_uris: post_logout_redirect_uris, launch_url: launch_url.presence
      )
      secret = app_client.generate_secret if app_client.client_type_confidential?
      raise ApiError.from_record(app_client) unless app_client.save

      recorder.record(action: "app_client.created", actor: @actor, target: app_client, metadata: { client_type: client_type })
      Created.new(app_client: app_client, client_secret: secret)
    end

    # @param app_client [AppClient]
    # @param changes [Hash] any of name, allowed_origins, redirect_uris, post_logout_redirect_uris, launch_url, enabled
    # @return [AppClient]
    def update(app_client, **changes)
      authorize!
      app_client.assign_attributes(changes.slice(:name, :allowed_origins, :redirect_uris, :post_logout_redirect_uris, :launch_url, :enabled)
        .tap { |slice| slice[:launch_url] = slice[:launch_url].presence if slice.key?(:launch_url) })
      changed = app_client.changes.transform_values { |from, to| { from: from, to: to } }

      AppClient.transaction do
        raise ApiError.from_record(app_client) unless app_client.save

        revoke_sessions(app_client) if changed.key?("enabled") && !app_client.enabled
      end

      recorder.record(action: "app_client.updated", actor: @actor, target: app_client, metadata: { changes: changed }) if changed.any?
      app_client
    end

    # Replaces a confidential client's secret. The old secret stops working immediately.
    # @param app_client [AppClient]
    # @return [Created]
    # @raise [ApiError] `conflict` for public clients
    def rotate_secret(app_client)
      authorize!
      raise ApiError.new(:conflict, message: "Public clients don't have a secret.") unless app_client.client_type_confidential?

      secret = app_client.generate_secret
      app_client.save!
      recorder.record(action: "app_client.secret_rotated", actor: @actor, target: app_client)
      Created.new(app_client: app_client, client_secret: secret)
    end

    # Deletes the client and signs out every session that was started through it.
    # @param app_client [AppClient]
    def destroy(app_client)
      authorize!
      AppClient.transaction do
        revoke_sessions(app_client)
        app_client.destroy!
      end
      recorder.record(action: "app_client.deleted", actor: @actor, target: app_client)
    end

    private

    def revoke_sessions(app_client)
      RefreshToken.active.where(app_client_id: app_client.id).update_all(revoked_at: Time.current)
    end

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_app_clients?
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
