# For SAML apps and SAML identity providers: whether they reach the project through its custom
# domain. Their SAML URLs and entity IDs follow, so switching means updating the other side's
# settings too. Without a verified domain they use the standard URLs.
module OnCustomDomain
  extend ActiveSupport::Concern

  included do
    validate :custom_domain_verified, if: -> { on_custom_domain && will_save_change_to_on_custom_domain? }
  end

  # @return [ProjectEndpoints] where the other side reaches the project
  def project_endpoints
    ProjectEndpoints.new(project, domain: (project.domains.status_verified.first if on_custom_domain))
  end

  private

  def custom_domain_verified
    errors.add(:on_custom_domain, "needs a verified custom domain") unless project&.domains&.status_verified&.exists?
  end
end
