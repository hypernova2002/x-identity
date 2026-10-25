module Oidc
  # Builds hosted login page URLs and appends parameters to redirect URIs.
  module Urls
    module_function

    # A hosted page on the project's standard URLs; see {ProjectEndpoints#hosted_page} for a custom domain's.
    # @param project [Project]
    # @param page [String] "login", "error", "signed-out" or "apps"
    # @param params [Hash]
    # @return [String]
    def hosted_page(project, page, **params)
      ProjectEndpoints.new(project).hosted_page(page, **params)
    end

    # @param uri [String]
    # @param params [Hash] nil values are left out
    # @return [String] the uri with the params added to its query
    def append_query(uri, **params)
      parsed = URI.parse(uri)
      parsed.query = [ parsed.query.presence, params.compact.to_query.presence ].compact.join("&").presence
      parsed.to_s
    end
  end
end
