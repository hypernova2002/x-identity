module EndUserAuth
  class PasskeyChallengeOptionsRequest < ClientRequest
    attribute :session, SignInFields::PasskeyChallengeSession
  end
end
