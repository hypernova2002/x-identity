module EndUserAuth
  class ProviderTokenRequest < ClientRequest
    attribute :code, RequestTypes::Token.meta(description: "From the redirect back to the app.")
    attribute :code_verifier, RequestTypes::T::String.constrained(min_size: 43, max_size: 128)
    attribute :redirect_uri, RequestTypes::T::String.constrained(min_size: 1, max_size: 2048)
      .meta(description: "The redirect URI the sign-in started with.")
  end
end
