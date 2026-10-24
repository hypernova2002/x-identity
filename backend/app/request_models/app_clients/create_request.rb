module AppClients
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name
    attribute :client_type, RequestTypes::T::String.enum(*AppClient.client_types.values)
      .meta(description: "public for browser and mobile apps; confidential for server-side apps that can keep a secret.")
    attribute? :machine, RequestTypes::T::Bool
      .meta(description: "A machine-to-machine app: confidential, with no browser settings, getting tokens for APIs with client credentials.")
    attribute? :allowed_origins, RequestTypes::Origins
    attribute? :redirect_uris, RequestTypes::RedirectUris
    attribute? :post_logout_redirect_uris, RequestTypes::RedirectUris
    attribute? :launch_url, RequestTypes::T::String.constrained(max_size: 2048).optional
      .meta(description: "Where the app portal opens the app. Apps without one aren't listed in the portal.")
      .meta(description: "Where apps may send users after logging out of hosted login, compared exactly.")
  end
end
