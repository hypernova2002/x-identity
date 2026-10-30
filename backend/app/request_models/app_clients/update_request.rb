module AppClients
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, Fields::Name
    attribute? :allowed_origins, Fields::AllowedOrigins
    attribute? :redirect_uris, Fields::RedirectUris
    attribute? :post_logout_redirect_uris, Fields::PostLogoutRedirectUris
    attribute? :launch_url, Fields::LaunchUrl
    attribute? :enabled, RequestTypes::T::Bool.meta(description: "Disabling a client signs out every session started through it.")
    attribute? :token_requests_per_minute, RequestTypes::TokenRequestsPerMinute.optional
      .meta(description: "Token endpoint requests allowed per minute for this client; null uses the project's limit.")
  end
end
