module Oidc
  # Limits each app client's requests to the token endpoint per minute: the app's own limit, or
  # its project's. Counts are kept in the shared counter store, so they hold across servers.
  class TokenRateLimit
    WINDOW = 1.minute

    # @param app_client [AppClient]
    # @param store [ActiveSupport::Cache::Store]
    def initialize(app_client, store: Rails.configuration.x.counter_store)
      @app_client = app_client
      @store = store
    end

    # Counts the request.
    # @raise [Error] `slow_down` (HTTP 429) once the client is over its limit this minute
    def check!
      window = Time.current.to_i / WINDOW.to_i
      count = @store.increment("token-requests:#{@app_client.id}:#{window}", 1, expires_in: WINDOW * 2)
      return if count.to_i <= @app_client.token_rate_limit

      retry_after = ((window + 1) * WINDOW.to_i) - Time.current.to_i
      raise Error.new("slow_down", "Too many token requests from this client; try again in #{retry_after} seconds.", retry_after: retry_after)
    end
  end
end
