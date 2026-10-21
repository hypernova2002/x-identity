# Decides which browser origins may call the API cross-origin: the console's own origins, and any
# origin an enabled app client lists. CORS only restricts browsers; it is not access control.
class CorsOriginPolicy
  # @param configured_origins [Array<String>] exact origins, e.g. `https://console.example.com`
  def initialize(configured_origins: ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?))
    @configured_origins = configured_origins
  end

  # @param origin [String, nil] the request's `Origin` header
  # @return [Boolean]
  def allowed?(origin)
    return false if origin.blank?

    @configured_origins.include?(origin) || AppClient.allows_origin?(origin)
  end
end
