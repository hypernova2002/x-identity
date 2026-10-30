module Me
  class ConfirmOtpRequest < ApplicationRequestModel
    attribute :code, RequestTypes::OtpCode.meta(description: "A code from the authenticator, to confirm it's set up.")
  end
end
