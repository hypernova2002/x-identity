module ApiGrants
  # Field types shared by the API grant requests.
  module Fields
    T = RequestTypes::T

    Scopes = T::Array.of(RequestTypes::ScopeName).constrained(max_size: ApiResource::MAX_SCOPES)
      .meta(description: "Scopes of the API the app may request.")
  end
end
