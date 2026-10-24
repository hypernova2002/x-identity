module ApiGrants
  class UpdateRequest < ApplicationRequestModel
    attribute :scopes, RequestTypes::T::Array.of(RequestTypes::T::String.constrained(max_size: 64)).constrained(max_size: ApiResource::MAX_SCOPES)
      .meta(description: "Scopes of the API the app may request.")
  end
end
