module ApiResources
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name
    attribute :identifier, RequestTypes::T::String.constrained(min_size: 3, max_size: 255)
      .meta(description: "The tokens' audience (aud), e.g. https://orders.example.com. Unique in the project, and can't be changed.")
    attribute? :scopes, RequestTypes::T::Array.of(ApiResources::ScopeRequest).constrained(max_size: ApiResource::MAX_SCOPES)
    attribute? :access_token_ttl_seconds, RequestTypes::T::Integer
      .constrained(gteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.min, lteq: ApiResource::ACCESS_TOKEN_TTL_SECONDS.max).optional
      .meta(description: "How long tokens for the API last, in seconds; null uses the project's access token lifetime.")
  end
end
