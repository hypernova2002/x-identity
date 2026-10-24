module ApiResources
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :scopes, RequestTypes::T::Array.of(ApiResources::ScopeRequest).constrained(max_size: ApiResource::MAX_SCOPES)
      .meta(description: "Replaces the API's scopes. Removed scopes are taken out of every app's grant.")
    attribute? :access_token_ttl_seconds, RequestTypes::T::Integer
      .constrained(gteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.min, lteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.max).optional
      .meta(description: "How long tokens for the API last, in seconds; null uses the project's access token lifetime.")
  end
end
