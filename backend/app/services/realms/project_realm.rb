module Realms
  # End users of one project. Their tokens are issued to, and only accepted for, the project's app clients.
  class ProjectRealm
    attr_reader :project

    # @param project [Project]
    # @param issuer [String, nil] tokens' `iss` when they're issued on a custom domain
    def initialize(project, issuer: nil)
      @project = project
      @custom_issuer = issuer.presence unless issuer == project.token_issuer
    end

    # @return [String, nil] the custom domain's issuer tokens are issued with, if not the standard one
    attr_reader :custom_issuer

    # @return [Project] owns the signing keys, lockout counters and auth configuration
    def owner
      project
    end

    # @return [Account]
    def account
      project.account
    end

    # @return [ActiveRecord::Relation<EndUser>]
    def users
      project.end_users
    end

    # @param subject [Object]
    # @return [Boolean] whether the subject is an end user of this project
    def owns?(subject)
      subject.is_a?(EndUser) && subject.project_id == project.id
    end

    # @return [AuthConfiguration]
    def auth_configuration
      project.auth_configuration!
    end

    # @return [String]
    def token_issuer
      custom_issuer || project.token_issuer
    end

    # @return [Array<String>] the standard issuer and the custom domain's: tokens from either are accepted anywhere
    def accepted_issuers
      ProjectEndpoints.issuers(project)
    end

    # @param issuer [String, nil]
    # @return [ProjectRealm]
    def with_issuer(issuer)
      self.class.new(project, issuer: issuer)
    end

    # @param app_client [AppClient]
    # @return [String] the client's `client_id`
    def audience_for(app_client)
      raise ArgumentError, "end-user tokens are issued through an app client" unless app_client&.project_id == project.id

      app_client.uid
    end

    # @param audience [String]
    # @return [Boolean] whether the audience is one of the project's enabled app clients
    def accepts_audience?(audience)
      project.app_clients.enabled.where(machine: false).exists?(uid: audience.to_s)
    end

    # @return [String] shown next to codes in authenticator apps
    def display_name
      "#{account.name} / #{project.name}"
    end

    # @return [String] prefix for audit actions about this realm's users, e.g. `end_user.signed_in`
    def event_prefix
      "end_user"
    end

    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param app_client [AppClient, nil]
    # @return [AuditEvents::Recorder]
    def recorder(ip: nil, user_agent: nil, app_client: nil)
      AuditEvents::Recorder.new(account: account, project: project, ip: ip, user_agent: user_agent, app_client: app_client)
    end
  end
end
