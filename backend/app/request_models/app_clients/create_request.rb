module AppClients
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name
    attribute :client_type, RequestTypes::T::String.enum(*AppClient.client_types.values)
      .meta(description: "public for browser and mobile apps; confidential for server-side apps that can keep a secret.")
    attribute? :allowed_origins, RequestTypes::Origins
    attribute? :redirect_uris, RequestTypes::RedirectUris
    attribute? :post_logout_redirect_uris, RequestTypes::RedirectUris
      .meta(description: "Where apps may send users after logging out of hosted login, compared exactly.")
  end
end
