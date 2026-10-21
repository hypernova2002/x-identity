module IdentityProviders
  # A provider's signing keys (JWKS), cached for an hour. A token signed with an unknown key id
  # triggers one refetch, at most once a minute, so rotated keys are picked up quickly.
  class KeySet
    TTL = 1.hour
    REFETCH_INTERVAL = 1.minute

    # @param http_client [HttpClient]
    # @param cache [ActiveSupport::Cache::Store]
    def initialize(http_client: HttpClient.new, cache: Rails.cache)
      @http_client = http_client
      @cache = cache
    end

    # @param jwks_uri [String]
    # @return [Proc] a `jwks:` loader for JWT.decode
    def loader(jwks_uri)
      lambda do |options|
        refetch = options[:kid_not_found] && @cache.write(refetch_key(jwks_uri), true, expires_in: REFETCH_INTERVAL, unless_exist: true)
        @cache.delete(cache_key(jwks_uri)) if refetch
        JWT::JWK::Set.new(keys(jwks_uri))
      end
    end

    private

    def keys(jwks_uri)
      @cache.fetch(cache_key(jwks_uri), expires_in: TTL) { @http_client.get_json(jwks_uri) }
    end

    def cache_key(jwks_uri)
      "identity_providers/jwks/#{OpenSSL::Digest::SHA256.hexdigest(jwks_uri)}"
    end

    def refetch_key(jwks_uri)
      "#{cache_key(jwks_uri)}/refetched"
    end
  end
end
