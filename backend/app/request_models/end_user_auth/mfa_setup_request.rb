module EndUserAuth
  class MfaSetupRequest < ClientRequest
    attribute :session, RequestTypes::Token
    attribute? :otp_type, RequestTypes::OtpType
  end
end
