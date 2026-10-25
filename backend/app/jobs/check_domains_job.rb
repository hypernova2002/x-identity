# Hourly: re-checks verified domains, so ones whose DNS records disappear are flagged, and pending
# ones, in case their own checks stopped.
class CheckDomainsJob < ApplicationJob
  queue_as :maintenance

  def perform
    ProjectDomain.where(status: %w[pending verified]).joins(:project).merge(Project.active).find_each do |domain|
      Domains::Verification.new(domain).call
    end
  end
end
