module Me
  class ConfirmOtpRequest < ApplicationRequestModel
    attribute :code, RequestTypes::OtpCode
  end
end
