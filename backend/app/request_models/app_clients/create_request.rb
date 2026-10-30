module AppClients
  class CreateRequest < ApplicationRequestModel
    attribute :name, Fields::Name
    attribute :client_type, RequestTypes::T::String.enum(*AppClient.client_types.values)
      .meta(description: "public for browser and mobile apps; confidential for server-side apps that can keep a secret. Can't be changed later.")
    attribute? :machine, RequestTypes::T::Bool
      .meta(description: "A machine-to-machine app: confidential, with no browser settings, getting tokens for APIs with client credentials.")
    attribute? :allowed_origins, Fields::AllowedOrigins
    attribute? :redirect_uris, Fields::RedirectUris
    attribute? :post_logout_redirect_uris, Fields::PostLogoutRedirectUris
    attribute? :launch_url, Fields::LaunchUrl
  end
end
