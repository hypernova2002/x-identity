module ApiGrants
  class CreateRequest < ApplicationRequestModel
    attribute :api_uid, RequestTypes::Uid
    attribute :scopes, RequestTypes::T::Array.of(RequestTypes::T::String.constrained(max_size: 64)).constrained(max_size: ApiResource::MAX_SCOPES)
      .meta(description: "Scopes of the API the app may request.")
  end
end
