module Me
  class StartOtpRequest < ApplicationRequestModel
    attribute? :otp_type, RequestTypes::OtpType
  end
end
