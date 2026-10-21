module AppClients
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name
    attribute :client_type, RequestTypes::T::String.enum(*AppClient.client_types.values)
      .meta(description: "public for browser and mobile apps; confidential for server-side apps that can keep a secret.")
    attribute? :allowed_origins, RequestTypes::Origins
  end
end
