module ApiResources
  class CreateRequest < ApplicationRequestModel
    attribute :name, Fields::Name
    attribute :identifier, RequestTypes::T::String.constrained(min_size: 3, max_size: 255)
      .meta(description: "The tokens' audience (aud), e.g. https://orders.example.com. Unique in the project, and can't be changed.")
    attribute? :scopes, Fields::Scopes.meta(description: "The scopes apps can be granted.")
    attribute? :access_token_ttl_seconds, Fields::AccessTokenTtlSeconds
  end
end
