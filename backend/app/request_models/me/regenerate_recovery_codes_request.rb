module Me
  class RegenerateRecoveryCodesRequest < ApplicationRequestModel
    attribute :code, RequestTypes::OtpCode
  end
end
