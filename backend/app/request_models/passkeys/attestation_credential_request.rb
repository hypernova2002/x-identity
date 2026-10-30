module Passkeys
  # A new passkey: the PublicKeyCredential from navigator.credentials.create.
  class AttestationCredentialRequest < ApplicationRequestModel
    attribute :id, Fields::CredentialId
    attribute :rawId, Fields::RawId
    attribute :type, Fields::CredentialType
    attribute? :authenticatorAttachment, Fields::AuthenticatorAttachment
    attribute? :clientExtensionResults, Fields::ClientExtensionResults
    attribute :response, AttestationResponseRequest.meta(description: "The authenticator's attestation of the new passkey.")
  end
end
