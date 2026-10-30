module Passkeys
  class AssertionResponseRequest < ApplicationRequestModel
    attribute :clientDataJSON, Fields::ClientDataJson
    attribute :authenticatorData, Fields::AuthenticatorData
    attribute :signature, Fields::Signature
    attribute? :userHandle, Fields::UserHandle
    attribute? :attestationObject, Fields::AttestationObject.optional
  end
end
