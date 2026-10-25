module Passkeys
  class FinishRegistrationRequest < ApplicationRequestModel
    attribute :registration_id, RequestTypes::Token
    attribute :credential, RequestTypes::T::Hash.meta(description: "The PublicKeyCredential the browser created, as JSON (its toJSON()).")
    attribute? :name, RequestTypes::T::String.constrained(max_size: 60).optional.meta(description: "Defaults to the browser and device, e.g. \"Safari on iPhone\".")
  end
end
