module Oidc
  # Builds hosted login page URLs in the web app and appends parameters to redirect URIs.
  module Urls
    module_function

    # @param project [Project]
    # @param page [String] "login", "error" or "signed-out"
    # @param params [Hash]
    # @return [String]
    def hosted_page(project, page, **params)
      base = "#{Rails.configuration.x.console_base_url}/auth/#{project.account.slug}/#{project.uid}/#{page}"
      query = params.compact.to_query
      query.empty? ? base : "#{base}?#{query}"
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
