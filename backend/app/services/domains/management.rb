module Domains
  # Adding, checking and removing a project's custom domain.
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

    # Adds a domain to verify. A project with a verified domain can add its replacement, which takes
    # over once verified.
    # @param hostname [String]
    # @return [ProjectDomain]
    # @raise [ApiError] `forbidden`, `conflict` or `validation_failed`
    def add(hostname:)
      authorize!
      unverified = @project.domains.where.not(status: "verified").first
      raise ApiError.new(:conflict, message: "Finish setting up #{unverified.hostname}, or remove it, first.") if unverified

      domain = @project.domains.new(hostname: hostname)
      ProjectDomain.transaction do
        raise ApiError.from_record(domain) unless domain.save

        record("domain.added", domain)
      end
      DomainVerificationJob.perform_later(domain_id: domain.id)
      domain
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.new(:conflict, message: "This domain is already being set up.")
    end

    # Checks the domain's DNS now, instead of waiting for the next automatic check.
    # @param domain [ProjectDomain]
    # @return [ProjectDomain]
    def check(domain)
      authorize!
      Verification.new(domain).call
    end

    # @param domain [ProjectDomain]
    def remove(domain)
      authorize!
      ProjectDomain.transaction do
        domain.destroy!
        record("domain.removed", domain)
      end
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_settings?
    end

    def record(action, domain)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: action, actor: @actor, target: domain, metadata: { hostname: domain.hostname })
    end
  end
end
