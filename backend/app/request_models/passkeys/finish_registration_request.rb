module Passkeys
  class FinishRegistrationRequest < ApplicationRequestModel
    attribute :registration_id, RequestTypes::Token.meta(description: "From the passkey registration options.")
    attribute :credential, AttestationCredentialRequest.meta(description: "The PublicKeyCredential the browser created, as JSON (its toJSON()).")
    attribute? :name, Fields::Name.optional.meta(description: "Defaults to the browser and device, e.g. \"Safari on iPhone\".")
  end
end
