module EndUserAuth
  class PasskeyChallengeOptionsRequest < ClientRequest
    attribute :session, RequestTypes::Token.meta(description: "The session of a challenge whose mfa_methods include passkey.")
  end
end
