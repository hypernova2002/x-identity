module Auth
  class MfaSetupRequest < ApplicationRequestModel
    attribute :session, RequestTypes::Token
    attribute? :otp_type, RequestTypes::OtpType
  end
end
