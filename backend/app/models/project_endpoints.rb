# Where a project's public endpoints and hosted pages are served: its standard URLs, or a verified
# custom domain. The issuer and every URL a sign-in hands out come from here, so a flow that starts
# on a custom domain stays on it.
class ProjectEndpoints
  attr_reader :project, :domain

  # @param project [Project]
  # @return [Array<String>] every issuer the project's tokens can carry
  def self.issuers(project)
    [ project.token_issuer, *project.domains.status_verified.map(&:base_url) ]
  end

  # @param project [Project]
  # @return [Array<ProjectEndpoints>] the standard URLs and the verified custom domain's, if any
  def self.all(project)
    [ new(project), *project.domains.status_verified.map { |domain| new(project, domain: domain) } ]
  end

  # @param project [Project]
  # @return [ProjectEndpoints] the custom domain once verified, for links sent outside a request (emails)
  def self.preferred(project)
    new(project, domain: project.domains.status_verified.first)
  end

  # The endpoints a flow started on, from the issuer stored with it. A domain removed since then
  # falls back to the standard URLs.
  # @param project [Project]
  # @param issuer [String, nil]
  # @return [ProjectEndpoints]
  def self.for_issuer(project, issuer)
    return new(project) if issuer.blank? || issuer == project.token_issuer

    new(project, domain: project.domains.status_verified.find { |domain| domain.base_url == issuer })
  end

  # @param project [Project]
  # @param domain [ProjectDomain, nil] a verified custom domain of the project
  def initialize(project, domain: nil)
    @project = project
    @domain = domain
  end

  # @return [String]
  def issuer
    domain ? domain.base_url : project.token_issuer
  end

  # @param path [String] e.g. "/oauth2/authorize"
  # @return [String]
  def url(path)
    "#{issuer}#{path}"
  end

  # @param page [String] "login", "error", "signed-out" or "apps"
  # @param params [Hash] nil values are left out
  # @return [String]
  def hosted_page(page, **params)
    base = domain ? "#{domain.base_url}/#{page}" : "#{Rails.configuration.x.console_base_url}/auth/#{project.account.slug}/#{project.uid}/#{page}"
    query = params.compact.to_query
    query.empty? ? base : "#{base}?#{query}"
  end

  # @return [String] the single sign-on cookie's path: the project's own on a shared host, all of a custom domain
  def cookie_path
    domain ? "/" : URI.parse(issuer).path
  end

  # @return [Boolean]
  def secure_cookie?
    issuer.start_with?("https://")
  end
end
