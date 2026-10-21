module EndUserAuth
  # Query parameters for starting a sign-in with an identity provider. There's no secret here:
  # confidential clients send theirs when redeeming the code.
  class ProviderAuthorizeRequest < ApplicationRequestModel
    attribute :client_id, RequestTypes::Uid.meta(description: "The app client's uid.")
    attribute :redirect_uri, RequestTypes::T::String.constrained(min_size: 1, max_size: 2048)
      .meta(description: "One of the app client's redirect URIs.")
    attribute :state, RequestTypes::T::String.constrained(min_size: 1, max_size: 512)
      .meta(description: "Returned unchanged; the app checks it to tie the response to its request.")
    attribute :code_challenge, RequestTypes::T::String.constrained(min_size: 43, max_size: 43)
      .meta(description: "base64url SHA-256 of a random code verifier, without padding.")
    attribute :code_challenge_method, RequestTypes::T::String.enum("S256")
  end
end
