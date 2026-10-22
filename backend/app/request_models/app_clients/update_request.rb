module AppClients
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :allowed_origins, RequestTypes::Origins
    attribute? :redirect_uris, RequestTypes::RedirectUris
    attribute? :post_logout_redirect_uris, RequestTypes::RedirectUris
    attribute? :launch_url, RequestTypes::T::String.constrained(max_size: 2048).optional
      .meta(description: "Where the app portal opens the app. Apps without one aren't listed in the portal.")
      .meta(description: "Where apps may send users after logging out of hosted login, compared exactly.")
    attribute? :enabled, RequestTypes::T::Bool.meta(description: "Disabling a client signs out every session started through it.")
  end
end
