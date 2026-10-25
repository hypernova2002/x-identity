module EndUserAuth
  class PasskeySetupRequest < ClientRequest
    attribute :session, RequestTypes::Token.meta(description: "The session of the passkey_setup challenge.")
  end
end
