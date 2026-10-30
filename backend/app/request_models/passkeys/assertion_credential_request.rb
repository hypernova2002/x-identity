module Passkeys
  # The browser's answer to a passkey sign-in: the PublicKeyCredential from navigator.credentials.get.
  class AssertionCredentialRequest < ApplicationRequestModel
    attribute :id, Fields::CredentialId
    attribute :rawId, Fields::RawId
    attribute :type, Fields::CredentialType
    attribute? :authenticatorAttachment, Fields::AuthenticatorAttachment
    attribute? :clientExtensionResults, Fields::ClientExtensionResults
    attribute :response, AssertionResponseRequest.meta(description: "The authenticator's signed answer.")
  end
end
