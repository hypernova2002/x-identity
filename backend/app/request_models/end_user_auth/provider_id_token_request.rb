module EndUserAuth
  class ProviderIdTokenRequest < ClientRequest
    attribute :id_token, RequestTypes::Jwt.meta(description: "The ID token the provider's SDK returned.")
    attribute :nonce, RequestTypes::T::String.constrained(min_size: 16, max_size: 256)
      .meta(description: "The random nonce the app generated for this sign-in; for Apple, the value before hashing.")
    attribute? :name, RequestTypes::Name.meta(description: "The user's name, for apps that receive it separately (Apple, first sign-in only).")
  end
end
