module Passkeys
  class AttestationResponseRequest < ApplicationRequestModel
    attribute :clientDataJSON, Fields::ClientDataJson
    attribute :attestationObject, Fields::AttestationObject
    attribute? :transports, Fields::Transports
    attribute? :authenticatorData, Fields::AuthenticatorData
    attribute? :publicKey, Fields::PublicKey
    attribute? :publicKeyAlgorithm, Fields::PublicKeyAlgorithm
  end
end
