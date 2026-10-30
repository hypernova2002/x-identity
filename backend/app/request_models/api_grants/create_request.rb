module ApiGrants
  class CreateRequest < ApplicationRequestModel
    attribute :api_uid, RequestTypes::Uid.meta(description: "The uid of the API the app is granted.")
    attribute :scopes, Fields::Scopes
  end
end
