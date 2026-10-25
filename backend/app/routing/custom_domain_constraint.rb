# Routes a request to a project's endpoints when its host is a verified custom domain of an active
# project. The domain is looked up once per request and left in it for controllers (see
# ApplicationController#custom_domain); hosts that aren't custom domains are remembered for a minute.
module CustomDomainConstraint
  ENV_KEY = "x_identity.custom_domain"
  CACHE_FOR = 1.minute

  module_function

  # @param request [ActionDispatch::Request]
  # @return [Boolean]
  def matches?(request)
    domain(request).present?
  end

  # @param request [ActionDispatch::Request]
  # @return [ProjectDomain, nil]
  def domain(request)
    return request.env[ENV_KEY] if request.env.key?(ENV_KEY)

    request.env[ENV_KEY] = lookup(request.host.to_s.downcase)
  end

  def lookup(host)
    return nil if platform_hosts.include?(host)

    id = Rails.cache.fetch([ "custom_domain_id", host ], expires_in: CACHE_FOR) do
      ProjectDomain.status_verified.joins(:project).merge(Project.active).where(hostname: host).pick(:id) || false
    end
    id ? ProjectDomain.status_verified.includes(project: :account).find_by(id: id) : nil
  end

  def platform_hosts
    [ Rails.configuration.x.app_base_url, Rails.configuration.x.console_base_url ].map { |url| URI.parse(url).host }
  end
end
