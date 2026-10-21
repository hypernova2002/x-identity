module EndUserAuth
  class MfaSetupRequest < ClientRequest
    attribute :session, RequestTypes::Token
  end
end
