module Domains
  # Where custom domains' TLS certificates come from. For now they're issued outside x-identity, by
  # a proxy that asks {Internal::DomainsController} before issuing one; a provider that issues them
  # itself plugs in here.
  module Certificates
    EXTERNAL = "external"

    module_function

    # @param _domain [ProjectDomain]
    # @return [String]
    def status_for(_domain)
      EXTERNAL
    end
  end
end
