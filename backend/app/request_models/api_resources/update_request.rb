module ApiResources
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, Fields::Name
    attribute? :scopes, Fields::Scopes.meta(description: "Replaces the API's scopes. Removed scopes are taken out of every app's grant.")
    attribute? :access_token_ttl_seconds, Fields::AccessTokenTtlSeconds
  end
end
