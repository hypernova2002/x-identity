module ApiResources
  # The project's APIs and which scopes machine-to-machine apps may request on them.
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

    # @param name [String]
    # @param identifier [String]
    # @param scopes [Array<Hash>] name and description
    # @param access_token_ttl_seconds [Integer, nil]
    # @return [ApiResource]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(name:, identifier:, scopes: [], access_token_ttl_seconds: nil)
      authorize!
      api = @project.api_resources.new(name: name, identifier: identifier, scopes: normalized(scopes), access_token_ttl_seconds: access_token_ttl_seconds)
      raise ApiError.from_record(api) unless api.save

      record("api.created", api, identifier: identifier)
      api
    end

    # @param api [ApiResource]
    # @param changes [Hash] any of name, scopes, access_token_ttl_seconds
    # @return [ApiResource]
    def update(api, **changes)
      authorize!
      changes[:scopes] = normalized(changes[:scopes]) if changes.key?(:scopes)
      api.assign_attributes(changes.slice(:name, :scopes, :access_token_ttl_seconds))
      changed = api.changes.transform_values { |from, to| { from: from, to: to } }

      ApiResource.transaction do
        raise ApiError.from_record(api) unless api.save

        api.api_grants.find_each { |grant| grant.update_columns(scopes: grant.scopes & api.scope_names) } if changed.key?("scopes")
      end
      record("api.updated", api, changes: changed) if changed.any?
      api
    end

    # Machine-to-machine apps lose access to the API; tokens already issued last until they expire.
    # @param api [ApiResource]
    def destroy(api)
      authorize!
      api.destroy!
      record("api.deleted", api, identifier: api.identifier)
    end

    # @param app_client [AppClient] a machine-to-machine app
    # @param api [ApiResource]
    # @param scopes [Array<String>]
    # @return [ApiGrant]
    def grant(app_client, api, scopes:)
      authorize!
      grant = app_client.api_grants.new(api_resource: api, scopes: scopes.uniq)
      raise ApiError.from_record(grant, field_names: { api_resource_id: :api_uid, api_resource: :api_uid }) unless grant.save

      record("api.access_granted", api, app_client: app_client.uid, scopes: grant.scopes)
      grant
    end

    # @param grant [ApiGrant]
    # @param scopes [Array<String>]
    # @return [ApiGrant]
    def update_grant(grant, scopes:)
      authorize!
      previous = grant.scopes
      raise ApiError.from_record(grant) unless grant.update(scopes: scopes.uniq)

      record("api.access_changed", grant.api_resource, app_client: grant.app_client.uid, scopes: { from: previous, to: grant.scopes })
      grant
    end

    # @param grant [ApiGrant]
    def revoke_grant(grant)
      authorize!
      grant.destroy!
      record("api.access_revoked", grant.api_resource, app_client: grant.app_client.uid)
    end

    private

    def normalized(scopes)
      Array(scopes).map { |scope| { "name" => scope[:name] || scope["name"], "description" => (scope[:description] || scope["description"]).presence }.compact }
    end

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_app_clients?
    end

    def record(action, api, **metadata)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: action, actor: @actor, target: api, metadata: metadata)
    end
  end
end
