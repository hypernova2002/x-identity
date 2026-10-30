module Passkeys
  class SignInRequest < ApplicationRequestModel
    attribute :authentication_id, SignInFields::PasskeyAuthenticationId
    attribute :credential, SignInFields::PasskeyCredential
  end
end
