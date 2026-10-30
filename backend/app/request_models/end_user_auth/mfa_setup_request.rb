module EndUserAuth
  class MfaSetupRequest < ClientRequest
    attribute :session, SignInFields::MfaSetupSession
  end
end
