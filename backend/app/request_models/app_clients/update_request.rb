module AppClients
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :allowed_origins, RequestTypes::Origins
    attribute? :redirect_uris, RequestTypes::RedirectUris
    attribute? :enabled, RequestTypes::T::Bool.meta(description: "Disabling a client signs out every session started through it.")
  end
end
