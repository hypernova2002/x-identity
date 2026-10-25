module Internal
  # Lets a TLS proxy ask whether to issue a certificate for a hostname, e.g. Caddy's on-demand TLS
  # `ask`: 200 for verified custom domains of active projects, 404 for anything else.
  class DomainsController < ApplicationController
    rate_limit to: 120, within: 1.minute

    def allowed
      hostname = params[:domain].to_s.strip.downcase.chomp(".")
      verified = ProjectDomain.status_verified.joins(:project).merge(Project.active).exists?(hostname: hostname)
      head(verified ? :ok : :not_found)
    end
  end
end
