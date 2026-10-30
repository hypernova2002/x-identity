module EndUserAuth
  class PasskeySetupRequest < ClientRequest
    attribute :session, SignInFields::PasskeySetupSession
  end
end
