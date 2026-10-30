module ApiResources
  # Field types shared by the API requests.
  module Fields
    T = RequestTypes::T

    Name = RequestTypes::Name.meta(description: "The API's name.")
    Scopes = T::Array.of(ApiResources::ScopeRequest).constrained(max_size: ApiResource::MAX_SCOPES)
    AccessTokenTtlSeconds = T::Integer
      .constrained(gteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.min, lteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.max).optional
      .meta(description: "How long tokens for the API last, in seconds; null uses the project's access token lifetime.")
  end
end
