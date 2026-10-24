module Oidc
  # The client_credentials grant: a machine-to-machine app gets an access token for one of the
  # project's APIs, limited to the scopes it was granted there. Every request is audited.
  class ClientCredentials
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param app_client [AppClient] already authenticated
    # @param params [Hash{String => String}] `audience` (the API's identifier) and optional `scope`
    # @return [Hash] the token response
    # @raise [Error] `unauthorized_client`, `invalid_request`, `invalid_target` or `invalid_scope`
    def call(app_client:, params:)
      refuse(app_client, "unauthorized_client", "Only machine-to-machine apps can use client_credentials.") unless app_client.machine?

      grant = grant_for(app_client, params["audience"].presence || params["resource"].presence)
      requested = params["scope"].to_s.split(" ").uniq
      scopes = requested.empty? ? grant.scopes : requested
      unless (scopes - grant.scopes).empty?
        refuse(app_client, "invalid_scope", "The app hasn't been granted #{(scopes - grant.scopes).join(' ')} on this API.", api: grant.api_resource)
      end

      tokens = Auth::TokenIssuer.new(realm: @project.realm, app_client: app_client).issue_for_client(api: grant.api_resource, scope: scopes.join(" "))
      recorder(app_client).record(
        action: "app_client.token_issued", actor: app_client, target: grant.api_resource,
        metadata: { audience: grant.api_resource.identifier, scope: scopes.join(" ") }
      )
      { access_token: tokens.access_token, token_type: "Bearer", expires_in: tokens.expires_in, scope: scopes.join(" ") }
    end

    private

    # The API named by `audience`, or the app's only API when there's just one.
    def grant_for(app_client, audience)
      grants = app_client.api_grants.includes(:api_resource)
      if audience.nil?
        return grants.first if grants.one?

        refuse(app_client, "invalid_request", "Name the API with the audience parameter.")
      end

      grant = grants.joins(:api_resource).find_by(api_resources: { identifier: audience })
      grant || refuse(app_client, "invalid_target", "The app hasn't been granted access to this API, or there's no such API.", audience: audience)
    end

    def refuse(app_client, code, description, api: nil, **metadata)
      recorder(app_client).record(
        action: "app_client.token_refused", actor: app_client, target: api,
        metadata: { error: code, audience: api&.identifier, **metadata }.compact
      )
      raise Error.new(code, description)
    end

    def recorder(app_client)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent, app_client: app_client)
    end
  end
end
