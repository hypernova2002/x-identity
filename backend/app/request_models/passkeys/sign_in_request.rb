module Passkeys
  class SignInRequest < ApplicationRequestModel
    attribute :authentication_id, RequestTypes::Token.meta(description: "From the passkey options.")
    attribute :credential, RequestTypes::T::Hash.meta(description: "The browser's answer (a PublicKeyCredential), as JSON (its toJSON()).")
  end
end
