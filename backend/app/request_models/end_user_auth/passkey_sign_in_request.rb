module EndUserAuth
  class PasskeySignInRequest < ClientRequest
    attribute :authentication_id, SignInFields::PasskeyAuthenticationId
    attribute :credential, SignInFields::PasskeyCredential
  end
end
