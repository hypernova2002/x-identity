module EndUserAuth
  class ProviderTokenRequest < ClientRequest
    attribute :code, RequestTypes::Token.meta(description: "From the redirect back to the app.")
    attribute :code_verifier, RequestTypes::T::String.constrained(min_size: 43, max_size: 128)
      .meta(description: "The random code verifier whose SHA-256 was sent as code_challenge.")
    attribute :redirect_uri, RequestTypes::Url.meta(description: "The redirect URI the sign-in started with.")
  end
end
